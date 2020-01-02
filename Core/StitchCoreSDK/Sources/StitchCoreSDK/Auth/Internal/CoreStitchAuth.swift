import Foundation
import MongoSwift

/**
 * The core class that holds and manages Stitch user authentication state. This class is meant to be inherited.
 *
 * - important: synchronization in this class happens around the activeUserAuthInfo and activeUser objects such
 *              that access to them is 1. always atomic and 2. queued to prevent excess token refreshes.
 *
 * - typeparameters
 *     - TStitchUser: The underlying user type for this `CoreStitchAuth`, which must conform to `CoreStitchUser`.
 */
open class CoreStitchAuth<TStitchUser>: StitchAuthRequestClient where TStitchUser: CoreStitchUser {
    // MARK: Stored Properties

    /**
     * The underlying authentication state of this `CoreStitchAuth`
     */
    internal var activeAuthStateHolder: AuthStateHolder = AuthStateHolder()

    /**
     * The `Storage` object indicating where authentication information should be persisted.
     */
    internal var storage: Storage

    /**
     * The thread that will proactively refresh the access token at fixed intervals.
     */
    private var refresherThread: Thread?

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
     * A `TStitchUser` object that represents the currently active and authenticated user
     * or `nil` if no user is currently active.
     */
    internal var activeUser: TStitchUser?

    /**
     * A Dictionary of `TStitchUser` objects mapped by by their `userID`.
     */
    internal var allUsersAuthInfo: [AuthInfo]

    /**
     * The getter and setter for authentication state, as represented by an `AuthInfo` object.
     */
    public internal(set) var activeUserAuthInfo: AuthInfo? {
        get {
            objc_sync_enter(authStateLock)
            defer { objc_sync_exit(authStateLock) }

            return activeAuthStateHolder.authInfo
        }
        set {
            objc_sync_enter(authStateLock)
            defer { objc_sync_exit(authStateLock) }
            activeAuthStateHolder.authInfo = newValue
        }
    }

    /**
     * Objects used by objc_sync_enter and objc_sync_exit as recursive mutexes to synchronize auth operations.
     */
    internal var authOperationLock = NSObject()
    internal var authStateLock = NSObject()

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
        self.allUsersAuthInfo = []

        // Retrieve all logged in users from storage
        do {
            let authInfos = try readCurrentUsersAuthInfoFromStorage()

            for authInfo in authInfos {
                allUsersAuthInfo.append(authInfo)
            }
        } catch {
            throw StitchError.clientError(withClientErrorCode: .couldNotLoadPersistedAuthInfo)
        }

        // Retrieve the active user from storage
        do {
            activeUserAuthInfo = try readActiveUserAuthInfoFromStorage()
        } catch {
            throw StitchError.clientError(withClientErrorCode: .couldNotLoadPersistedAuthInfo)
        }

        if let activeUserAuthInfo = activeUserAuthInfo, activeUserAuthInfo.hasUser {
            self.activeUser = try makeStitchUser(withAuthInfo: activeUserAuthInfo)
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
    open func dispatchAuthEvent(_ authEvent: AuthRebindEvent) {
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
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        return activeUserAuthInfo?.isLoggedIn ?? false
    }

    /**
     * The currently authenticated user as a `TStitchUser`, or `nil` if no user is currently authenticated.
     */
    public var user: TStitchUser? {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        return self.activeUser
    }

    /**
     * Returns whether or not the current authentication state has a meaningful device id.
     */
    public var hasDeviceID: Bool {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        return activeUserAuthInfo?.deviceID != nil
            && activeUserAuthInfo?.deviceID != ""
            && activeUserAuthInfo?.deviceID != "000000000000000000000000"
    }

    /**
     * Returns the currently authenticated user's device id, or `nil` is no user is currently authenticated, or if the
     * device id does not exist.
     */
    public var deviceID: String? {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        return activeUserAuthInfo?.deviceID
    }

    // MARK: Refresh Access Token
    /**
     * Attempts to refresh the current access token.
     *
     * - important: This method must be called within a lock.
     */
    public func refreshAccessToken() throws {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        // Get the new access token and update the activeUserAuthInfo
        let newAccessToken = try doRefreshAccessToken()
        activeUserAuthInfo = activeUserAuthInfo?.update(withAccessToken: newAccessToken.accessToken)

        if let user = activeUser as? CoreStitchUserImpl {
            let userData = try StitchJWT.init(fromEncodedJWT: newAccessToken.accessToken).userData
            user.backingCustomData = userData
        }


        if let authInfo = self.activeUserAuthInfo, let userID = authInfo.userID {
            // Update the user in the list of all users
            if let index = allUsersAuthInfo.firstIndex(where: {$0.userID == userID}) {
                allUsersAuthInfo[index] = authInfo
                try? writeCurrentUsersAuthInfoToStorage()
            }

            try writeActiveUserAuthInfoToStorage(activeAuthInfo: authInfo)
        }
    }

    /**
     * Checks if the current access token is expired or going to expire soon, and refreshes the access token if
     * necessary.
     */
    internal func tryRefreshAccessToken(reqStartedAt: TimeInterval) throws {
        // use this critical section to create a queue of pending outbound requests
        // that should wait on the result of doing a token refresh or logout. This will
        // prevent too many refreshes happening one after the other.
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        guard isLoggedIn, let accessToken = activeUserAuthInfo?.accessToken else {
            throw StitchError.clientError(withClientErrorCode: .loggedOutDuringRequest)
        }

        let jwt = try StitchJWT.init(fromEncodedJWT: accessToken)
        guard let issuedAt = jwt.issuedAt,
            issuedAt < reqStartedAt else {
                return
        }
        try refreshAccessToken()
    }

    /**
     * Performs the request necessary to refresh an access token.
     *
     * - return: a new APIAccessToken representing the refreshed access token.
     */
    internal func doRefreshAccessToken() throws -> APIAccessToken {
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

        return newAccessToken
    }

    /**
     * Helper function to make a TStitchUser if possible otherwise return nil
     */
    internal func makeStitchUser(withAuthInfo authInfo: AuthInfo) throws -> TStitchUser {
        // Only return user if it has the required properties
        guard let userID = authInfo.userID,
              let userProfile = authInfo.userProfile,
              let lastAuthActivity = authInfo.lastAuthActivity,
              let loggedInProviderType = authInfo.loggedInProviderType,
              let loggedInProviderName = authInfo.loggedInProviderName,
              let accessToken = authInfo.accessToken else {
                throw StitchError.clientError(withClientErrorCode: .userNotValid)
        }

        return self.userFactory.makeUser(
            withID: userID,
            withLoggedInProviderType: loggedInProviderType,
            withLoggedInProviderName: loggedInProviderName,
            withUserProfile: userProfile,
            withIsLoggedIn: authInfo.isLoggedIn,
            withLastAuthActivity: lastAuthActivity,
            customData: try StitchJWT.init(fromEncodedJWT: accessToken).userData)
    }
}
