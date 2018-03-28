import Foundation
import ExtendedJSON

private enum AuthKey: String {
    case options
    case device
}

/**
 * synchronization in this class happens around the authInfo and currentUser objects such that
 * access to them is 1. always atomic and 2. queued to prevent excess token refreshes.
 *
 * @param <TStitchUser>
 */
open class CoreStitchAuth<TStitchUser> where TStitchUser: CoreStitchUser {
    internal var authStateHolder = AuthStateHolder()
    private var storage: Storage
    private var refresherThread: Thread?
    private var currentUser: TStitchUser?

    public let requestClient: StitchRequestClient
    public let authRoutes: StitchAuthRoutes
    public internal(set) var authInfo: AuthInfo? {
        get {
            return authStateHolder.authInfo
        }
        set {
            authStateHolder.authInfo = newValue
        }
    }

    public init(requestClient: StitchRequestClient,
                authRoutes: StitchAuthRoutes,
                storage: Storage) throws {
        self.requestClient = requestClient
        self.authRoutes = authRoutes
        self.storage = storage

        self.authStateHolder.authInfo = try StoreAuthInfo.read(fromStorage: storage)

        if let authInfo = authInfo {
            // this implies other properties we are interested should be set
            self.currentUser =
                self.userFactory
                    .makeUser(withId: authInfo.userId,
                              withLoggedInProviderType: authInfo.loggedInProviderType,
                              withLoggedInProviderName: authInfo.loggedInProviderName,
                              withUserProfile: authInfo.userProfile)
        }

        self.refresherThread = Thread.init(target: self,
                                           selector: #selector(doRunAccessTokenRefresher),
                                           object: nil)

        self.refresherThread?.start()
    }

    @objc private func doRunAccessTokenRefresher() {
        AccessTokenRefresher<TStitchUser>(authRef: self).run()
    }

    deinit {
        refresherThread?.cancel()
    }

    open var userFactory: AnyStitchUserFactory<TStitchUser> {
        fatalError("not implemented")
    }

    open func onAuthEvent() {
        fatalError("not implemented")
    }

    open var deviceInfo: Document {
        fatalError("deviceInfo must be implemented")
    }

    public var isLoggedIn: Bool {
        // swiftlint:disable force_try
        return try! sync(self) {
            // swiftlint:enable force_try
            self.authStateHolder.isLoggedIn
        }
    }

    public var user: TStitchUser? {
        // swiftlint:disable force_try
        return try! sync(self) {
            // swiftlint:enable force_try
            self.currentUser
        }
    }

    public func loginWithCredentialBlocking(withCredential credential: StitchCredential) throws -> TStitchUser {
        return try sync(self) {
            if !isLoggedIn {
                return try doLogin(withCredential: credential, asLinkRequest: false)
            }

            if credential.providerCapabilities.reusesExistingSession {
                if credential.providerType == currentUser?.loggedInProviderType {
                    return self.currentUser!
                }
            }

            try logoutBlocking()
            return try doLogin(withCredential: credential, asLinkRequest: false)
        }
    }

    public func linkUserWithCredentialBlocking(withUser user: TStitchUser,
                                               withCredential credential: StitchCredential) throws -> TStitchUser {
        return try sync(self) {
            guard let currentUser = self.currentUser,
                user == currentUser else {
                throw StitchError.requestError(
                    withMessage: "user no longer valid; please try again with a new user from StitchAuth.user")
            }

            return try self.doLogin(withCredential: credential, asLinkRequest: true)
        }
    }

    public func logoutBlocking() throws {
        guard isLoggedIn else { return }

        do {
            try doLogout()
        } catch StitchError.serviceError {
        } catch let err {
            try clearAuth()
            throw err
        }

        try clearAuth()
    }

    public var hasDeviceId: Bool {
        return authInfo?.deviceId != nil
            && authInfo?.deviceId != ""
            && authInfo?.deviceId != "000000000000000000000000"
    }

    public var deviceId: String? {
        return authInfo?.deviceId
    }

    // use this critical section to create a queue of pending outbound requests
    // that should wait on the result of doing a token refresh or logout. This will
    // prevent too many refreshes happening one after the other.
    internal func tryRefreshAccessToken(reqStartedAt: TimeInterval) throws {
        try sync(self) {
            guard isLoggedIn, let accessToken = self.authStateHolder.accessToken else {
                throw StitchError.requestError(withMessage: "logged out during request")
            }

            let jwt = try DecodedJWT.init(jwt: accessToken)
            guard let issuedAt = jwt.issuedAt,
                issuedAt.timeIntervalSince1970 < reqStartedAt else {
                return
            }
            try refreshAccessToken()
        }
    }

    /// NOTE: This method must be called within a lock
    internal func refreshAccessToken() throws {
        let response = try self.doAuthenticatedRequest(StitchAuthRequestBuilderImpl {
            $0.useRefreshToken = true
            $0.path = self.authRoutes.sessionRoute
            $0.method = .post
        }.build())

        let newAccessToken = try JSONDecoder().decode(APIAccessToken.self,
                                                   from: response.body!)

        self.authInfo = self.authInfo?.refresh(withNewAccessToken: newAccessToken)

        try self.authInfo?.write(toStorage: &self.storage)
    }

    private func attachAuthOptions(authBody: inout Document) {
        authBody[AuthKey.options.rawValue] = [
            AuthKey.device.rawValue: deviceInfo
        ] as Document
    }

    // callers of doLogin should be synchronized before calling in.
    private func doLogin(withCredential credential: StitchCredential, asLinkRequest: Bool) throws -> TStitchUser {
        let response = try self.doLoginRequest(withCredential: credential,
                                               asLinkRequest: asLinkRequest)
        let user = try self.processLoginResponse(withCredential: credential,
                                                 forResponse: response)

        onAuthEvent()

        return user
    }

    private func doLoginRequest(withCredential credential: StitchCredential,
                                asLinkRequest: Bool) throws -> Response {
        let reqBuilder = StitchDocRequestBuilderImpl {
            $0.method = .post
            if asLinkRequest {
                $0.path = authRoutes.authProviderLinkRoute(withProviderName: credential.providerName)
            } else {
                $0.path = authRoutes.authProviderLoginRoute(withProviderName: credential.providerName)
            }

            var body = credential.material
            self.attachAuthOptions(authBody: &body)
            $0.document = body
        }

        if !asLinkRequest {
            return try self.requestClient.doJSONRequestRaw(reqBuilder.build())
        }

        return try doAuthenticatedJSONRequestRaw(try StitchAuthDocRequestBuilderImpl {
            $0.body = reqBuilder.body
            $0.path = reqBuilder.path
            $0.headers = reqBuilder.headers
            $0.method = reqBuilder.method
            $0.document = reqBuilder.document
        }.build())
    }

    private func processLoginResponse(withCredential credential: StitchCredential,
                                      forResponse response: Response) throws -> TStitchUser {
        guard let body = response.body else {
            throw StitchErrorCode.missingAuthReq
        }

        let decodedInfo = try JSONDecoder().decode(APIAuthInfoImpl.self, from: body)

        // Provisionally set so we can make a profile request
        if self.authInfo == nil {
            self.authStateHolder.apiAuthInfo = decodedInfo
        } else {
            self.authInfo =
                self.authInfo?.merge(withPartialInfo: decodedInfo,
                                     fromOldInfo: self.authInfo!)
        }

        var profile: StitchUserProfile!
        do {
            profile = try doGetUserProfile()
        } catch let err {
            try self.logoutBlocking()
            throw err
        }

        // Finally set the info and user
        self.authInfo = StoreAuthInfo.init(
            withAPIAuthInfo: decodedInfo,
            withExtendedAuthInfo: ExtendedAuthInfoImpl.init(loggedInProviderType: credential.providerType,
                                                            loggedInProviderName: credential.providerName,
                                                            userProfile: profile)
        )

        try self.authInfo?.write(toStorage: &storage)
        self.currentUser =
            userFactory
                .makeUser(
                    withId: authInfo!.userId,
                    withLoggedInProviderType: credential.providerType,
                    withLoggedInProviderName: credential.providerName,
                    withUserProfile: profile)
        return self.currentUser!
    }

    private func doGetUserProfile() throws -> StitchUserProfile {
        let response = try doAuthenticatedRequest(StitchAuthRequestBuilderImpl {
            $0.method = .get
            $0.path = self.authRoutes.profileRoute
        }.build())

        let decodedProfile = try JSONDecoder.init().decode(APICoreUserProfileImpl.self,
                                                           from: response.body!)

        return StitchUserProfileImpl.init(userType: decodedProfile.userType,
                                          identities: decodedProfile.identities,
                                          data: decodedProfile.data)
    }

    @discardableResult
    private func doLogout() throws -> Response {
        return try self.doAuthenticatedRequest(StitchAuthRequestBuilderImpl {
            $0.useRefreshToken = true
            $0.path = authRoutes.sessionRoute
            $0.method = .delete
        }.build())
    }

    internal func clearAuth() throws {
        try sync(self) {
            guard self.isLoggedIn else { return }
            self.authStateHolder.clearState()
            StoreAuthInfo.clear(storage: &storage)
            currentUser = nil
            onAuthEvent()
        }
    }
}
