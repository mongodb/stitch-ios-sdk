import Foundation
import MongoSwift

/**
 * The core class that holds and manages Stitch user authentication state. This class is meant to be inherited.
 *
 * - important: synchronization in this class happens around the authInfo and currentUser objects such that
 *              access to them is 1. always atomic and 2. queued to prevent excess token refreshes.
 *
 * - typeparameters
 *     - TStitchUser: The underlying user type for this `CoreStitchAuth`, which must conform to `CoreStitchUser`.
 */
open class CoreStitchAuth<TStitchUser>: StitchAuthRequestClient where TStitchUser: CoreStitchUser {
    // MARK: Stored Properties

    /**
     * The underlying authentication state of this `CoreStitchAuth`
     */
    internal var authStateHolder: AuthStateHolder = AuthStateHolder()

    /**
     * The `Storage` object indicating where authentication information should be persisted.
     */
    internal var storage: Storage

    /**
     * The thread that will proactively refresh the access token at fixed intervals.
     */
    private var refresherThread: Thread?

    /**
     * A `TStitchUser` object that represents the currently authenticated user, or `nil` if no one is authenticated.
     */
    private var currentUser: TStitchUser?

    /**
     * The `StitchRequestClient` used by the `CoreStitchAuth` to make requests to the Stitch server.
     */
    public let requestClient: StitchRequestClient

    /**
     * The `StitchAuthRoutes` object representing the authentication API routes of the Stitch server for the current
     * app.
     */
    public let authRoutes: StitchAuthRoutes

    /**
     * The getter and setter for authentication state, as represented by an `AuthInfo` object.
     */
    public internal(set) var authInfo: AuthInfo? {
        get {
            return authStateHolder.authInfo
        }
        set {
            authStateHolder.authInfo = newValue
            authStateHolder.apiAuthInfo = newValue
            authStateHolder.extendedAuthInfo = newValue
        }
    }

    // MARK: Initialization

    /**
     * Initializes the `CoreStitchAuth` with a request client, authentication API routes, and a `Storage` indicating
     * where the `CoreStitchAuth` should persist authentication information. This initializer will start a `Thread`
     * that will proactively refresh the access token at fixed intervals.
     */
    public init(requestClient: StitchRequestClient,
                authRoutes: StitchAuthRoutes,
                storage: Storage,
                startRefresherThread: Bool = true) throws {
        self.requestClient = requestClient
        self.authRoutes = authRoutes
        self.storage = storage

        do {
            self.authStateHolder.authInfo = try StoreAuthInfo.read(fromStorage: storage)
        } catch {
            throw StitchError.clientError(withClientErrorCode: .couldNotLoadPersistedAuthInfo)
        }

        if let authInfo = authInfo {
            // this implies other properties we are interested should be set
            self.currentUser =
                self.userFactory
                    .makeUser(withID: authInfo.userID,
                              withLoggedInProviderType: authInfo.loggedInProviderType,
                              withLoggedInProviderName: authInfo.loggedInProviderName,
                              withUserProfile: authInfo.userProfile)
        }
        
        if startRefresherThread {
            self.refresherThread = Thread.init(target: self,
                                               selector: #selector(doRunAccessTokenRefresher),
                                               object: nil)

            self.refresherThread?.start()
        }
    }

    /**
     * Instantiates an access token refresher and begins its infinite loop.
     *
     * - important: Should only be called on a standalone non-main thread.
     */
    @objc private func doRunAccessTokenRefresher() {
        AccessTokenRefresher<TStitchUser>(authRef: self).run()
    }

    /**
     * Cancels the access token refresher thread.
     */
    deinit {
        refresherThread?.cancel()
    }

    // MARK: Unimplemented Methods and Properties

    /**
     * Should return an `AnyStitchUserFactory` object, capable of constructing users of the `TStitchUser` type.
     */
    open var userFactory: AnyStitchUserFactory<TStitchUser> {
        fatalError("not implemented")
    }

    /**
     * A method that will be called whenever an authentication event (logging in, logging out, linking) occurs.
     */
    open func onAuthEvent() {
        fatalError("not implemented")
    }

    /**
     * A method that should return a BSON Document containing information about the current device.
     */
    open var deviceInfo: Document {
        var info = Document()
        if hasDeviceID {
            info[DeviceField.deviceID.rawValue] = self.deviceID
        }
        return info
    }

    // MARK: Computed Properties

    /**
     * Whether or not a user is currently logged in.
     */
    public var isLoggedIn: Bool {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        return self.authStateHolder.isLoggedIn
    }

    /**
     * The currently authenticated user as a `TStitchUser`, or `nil` if no user is currently authenticated.
     */
    public var user: TStitchUser? {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        return self.currentUser
    }

    /**
     * Returns whether or not the current authentication state has a meaningful device id.
     */
    public var hasDeviceID: Bool {
        return authInfo?.deviceID != nil
            && authInfo?.deviceID != ""
            && authInfo?.deviceID != "000000000000000000000000"
    }

    /**
     * Returns the currently authenticated user's device id, or `nil` is no user is currently authenticated, or if the
     * device id does not exist.
     */
    public var deviceID: String? {
        return authInfo?.deviceID
    }

    // MARK: Authentication Actions

    /**
     * Authenticates the `CoreStitchAuth` using the provided `StitchCredential. Blocks the current thread until the
     * request is completed.
     */
    public func loginWithCredentialInternal(withCredential credential: StitchCredential) throws -> TStitchUser {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        if !isLoggedIn {
            return try doLogin(withCredential: credential, asLinkRequest: false)
        }

        if credential.providerCapabilities.reusesExistingSession {
            if type(of: credential).providerType == currentUser?.loggedInProviderType {
                return self.currentUser!
            }
        }

        logoutInternal()
        return try doLogin(withCredential: credential, asLinkRequest: false)
    }

    /**
     * Links the currently logged in user with a new identity represented by the provided `StitchCredential. Blocks the
     * current thread until the request is completed.
     */
    public func linkUserWithCredentialInternal(withUser user: TStitchUser,
                                               withCredential credential: StitchCredential) throws -> TStitchUser {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        guard let currentUser = self.currentUser,
            user == currentUser else {
            throw StitchError.clientError(withClientErrorCode: .userNoLongerValid)
        }

        return try self.doLogin(withCredential: credential, asLinkRequest: true)
    }

    /**
     * Logs out the current user, and clears authentication state from this `CoreStitchAuth` as well as underlying
     * storage. Blocks the current thread until the request is completed. If the logout request fails, this method will
     * still clear local authentication state.
     */
    public func logoutInternal() {
        guard isLoggedIn else { return }

        _ = try? self.doLogout()
        clearAuth()
    }

    // MARK: Internal Methods

    /**
     * Performs the logic of logging in this `CoreStitchAuth` as a new user with the provided credential. Can also
     * perform a user link if the `asLinkRequest` parameter is true.
     *
     * - important: Callers of `doLogin` should be synchronized before calling in.
     */
    private func doLogin(withCredential credential: StitchCredential, asLinkRequest: Bool) throws -> TStitchUser {
        let response = try self.doLoginRequest(withCredential: credential, asLinkRequest: asLinkRequest)
        let user = try self.processLoginResponse(withCredential: credential,
                                                 forResponse: response,
                                                 asLinkRequest: asLinkRequest)

        onAuthEvent()
        return user
    }

    /**
     * Enum representing the keys for additional auth options that may be attached to the body of the authentication
     * request sent to the Stitch server on login or link.
     */
    private enum AuthKey: String {
        case options
        case device
    }

    /**
     * Attaches authentication options to the BSON document passed in as the `authBody` parameter. Necessary for the
     * the login request.
     */
    private func attachAuthOptions(authBody: inout Document) {
        authBody[AuthKey.options.rawValue] = [AuthKey.device.rawValue: deviceInfo] as Document
    }

    /**
     * Performs the login request against the Stitch server. If `asLinkRequest` is true, a link request is performed
     * instead.
     */
    private func doLoginRequest(withCredential credential: StitchCredential,
                                asLinkRequest: Bool) throws -> Response {
        let reqBuilder = StitchDocRequestBuilder()
        
        reqBuilder.with(method: .post)
        
        if asLinkRequest {
            reqBuilder.with(path: authRoutes.authProviderLinkRoute(withProviderName: credential.providerName))
        } else {
            reqBuilder.with(path: authRoutes.authProviderLoginRoute(withProviderName: credential.providerName))
        }
        
        var body = credential.material
        self.attachAuthOptions(authBody: &body)
        reqBuilder.with(document: body)

        if !asLinkRequest {
            return try self.requestClient.doRequest(reqBuilder.build())
        }
        
        return try doAuthenticatedRequest(
            StitchAuthDocRequest.init(stitchRequest: reqBuilder.build(), document: body)
        )
    }

    /**
     * Processes the response of the login/link request, setting the authentication state if appropriate, and
     * requesting the user profile in a separate request.
     */
    private func processLoginResponse(withCredential credential: StitchCredential,
                                      forResponse response: Response,
                                      asLinkRequest: Bool) throws -> TStitchUser {
        guard let body = response.body else {
            throw StitchError.serviceError(
                withMessage: StitchErrorCodable.genericErrorMessage(withStatusCode: response.statusCode),
                withServiceErrorCode: .unknown
            )
        }

        var decodedInfo: APIAuthInfoImpl!
        do {
            decodedInfo = try JSONDecoder().decode(APIAuthInfoImpl.self, from: body)
        } catch {
            throw StitchError.requestError(withError: error, withRequestErrorCode: .decodingError)
        }

        let oldAuthInfo = self.authInfo
        let oldUser = self.user

        // Provisionally set auth info so we can make a profile request
        var newAPIAuthInfo: APIAuthInfo!
        if let oldAuthInfo = oldAuthInfo { // If there was existing auth info (as in a link request)
            let newAuthInfo = oldAuthInfo.merge(
                withPartialInfo: decodedInfo,
                fromOldInfo: oldAuthInfo
            )
            newAPIAuthInfo = newAuthInfo

            self.authInfo = newAuthInfo
        } else { // If there was no existing auth info
            newAPIAuthInfo = decodedInfo
            self.authStateHolder.apiAuthInfo = decodedInfo
        }

        var profile: StitchUserProfile!
        do {
            profile = try doGetUserProfile()
        } catch let err {
            // If this was a link request, back out of setting authInfo and reset any created user. This will keep
            // the currently logged in user logged in if the profile request failed, and in this particular edge case
            // the user is linked, but they are logged in with their older credentials.
            if asLinkRequest {
                self.authInfo = oldAuthInfo
                currentUser = oldUser
            } else { // otherwise if this was a normal login request, log the user out
                self.authInfo = nil
                currentUser = nil
            }
    
            throw err
        }
        
        // Finally set the info and user
        self.authInfo = StoreAuthInfo.init(
            withAPIAuthInfo: newAPIAuthInfo,
            withExtendedAuthInfo: ExtendedAuthInfoImpl.init(loggedInProviderType: type(of: credential).providerType,
                                                            loggedInProviderName: credential.providerName,
                                                            userProfile: profile))

        // Persist auth info to storage
        do {
            try self.authInfo?.write(toStorage: &storage)
        } catch {
            throw StitchError.clientError(withClientErrorCode: .couldNotPersistAuthInfo)
        }

        self.currentUser =
            userFactory
                .makeUser(
                    withID: authInfo!.userID,
                    withLoggedInProviderType: type(of: credential).providerType,
                    withLoggedInProviderName: credential.providerName,
                    withUserProfile: profile)
        return self.currentUser!
    }

    /**
     * Performs a request against the Stitch server to get the currently authenticated user's profile.
     */
    private func doGetUserProfile() throws -> StitchUserProfile {
        let response = try doAuthenticatedRequest(
            StitchAuthRequestBuilder()
                .with(method: .get)
                .with(path: self.authRoutes.profileRoute)
                .build()
        )

        var decodedProfile: APICoreUserProfileImpl!
        do {
            decodedProfile = try JSONDecoder.init().decode(APICoreUserProfileImpl.self, from: response.body!)
        } catch {
            throw StitchError.requestError(withError: error, withRequestErrorCode: .decodingError)
        }

        return StitchUserProfileImpl.init(userType: decodedProfile.userType,
                                          identities: decodedProfile.identities,
                                          data: decodedProfile.data)
    }

    /**
     * Performs a logout request against the Stitch server.
     */
    @discardableResult
    private func doLogout() throws -> Response {
        return try self.doAuthenticatedRequest(
            StitchAuthRequestBuilder()
                .withRefreshToken()
                .with(path: authRoutes.sessionRoute)
                .with(method: .delete)
                .build()
        )
    }

    /**
     * Clears the `CoreStitchAuth`'s authentication state, as well as associated authentication state in underlying
     * storage.
     */
    internal func clearAuth() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        guard self.isLoggedIn else { return }
        self.authStateHolder.clearState()
        StoreAuthInfo.clear(storage: &storage)
        currentUser = nil
        onAuthEvent()
    }
    
    /**
     * Checks if the current access token is expired or going to expire soon, and refreshes the access token if
     * necessary.
     */
    internal func tryRefreshAccessToken(reqStartedAt: TimeInterval) throws {
        // use this critical section to create a queue of pending outbound requests
        // that should wait on the result of doing a token refresh or logout. This will
        // prevent too many refreshes happening one after the other.
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        guard isLoggedIn, let accessToken = self.authStateHolder.accessToken else {
            throw StitchError.clientError(withClientErrorCode: .loggedOutDuringRequest)
        }
        
        let jwt = try JWT.init(fromEncodedJWT: accessToken)
        guard let issuedAt = jwt.issuedAt,
            issuedAt < reqStartedAt else {
                return
        }
        try refreshAccessToken()
    }
    
    /**
     * Attempts to refresh the current access token.
     *
     * - important: This method must be called within a lock.
     */
    internal func refreshAccessToken() throws {
        let response = try self.doAuthenticatedRequest(
            StitchAuthRequestBuilder()
                .withRefreshToken()
                .with(path: self.authRoutes.sessionRoute)
                .with(method: .post)
                .build()
        )
        
        var newAccessToken: APIAccessToken!
        do {
            newAccessToken = try JSONDecoder().decode(APIAccessToken.self,
                                                      from: response.body!)
        } catch let err {
            throw StitchError.requestError(withError: err, withRequestErrorCode: .decodingError)
        }
        
        self.authInfo = self.authInfo?.refresh(withNewAccessToken: newAccessToken)
        
        do {
            try self.authInfo?.write(toStorage: &self.storage)
        } catch {
            throw StitchError.clientError(withClientErrorCode: .couldNotPersistAuthInfo)
        }
    }
}
