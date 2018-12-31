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
    internal var currentUser: TStitchUser?

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
            objc_sync_enter(authStateLock)
            defer { objc_sync_exit(authStateLock) }

            return authStateHolder.authInfo
        }
        set {
            authStateHolder.authInfo = newValue
            authStateHolder.apiAuthInfo = newValue
            authStateHolder.extendedAuthInfo = newValue
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
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        return self.authStateHolder.isLoggedIn
    }

    /**
     * The currently authenticated user as a `TStitchUser`, or `nil` if no user is currently authenticated.
     */
    public var user: TStitchUser? {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        return self.currentUser
    }

    /**
     * Returns whether or not the current authentication state has a meaningful device id.
     */
    public var hasDeviceID: Bool {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        return authInfo?.deviceID != nil
            && authInfo?.deviceID != ""
            && authInfo?.deviceID != "000000000000000000000000"
    }

    /**
     * Returns the currently authenticated user's device id, or `nil` is no user is currently authenticated, or if the
     * device id does not exist.
     */
    public var deviceID: String? {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        return authInfo?.deviceID
    }

    // MARK: Authentication Actions

    /**
     * Authenticates the `CoreStitchAuth` using the provided `StitchCredential. Blocks the current thread until the
     * request is completed.
     */
    public func loginWithCredentialInternal(withCredential credential: StitchCredential) throws -> TStitchUser {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

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
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

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
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        guard isLoggedIn else { return }

        _ = try? self.doLogout()
        clearAuth()
    }

    // MARK: Internal Methods

    /**
     * Clears the `CoreStitchAuth`'s authentication state, as well as associated authentication state in underlying
     * storage.
     */
    internal func clearAuth() {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

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
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        guard isLoggedIn, let accessToken = self.authStateHolder.accessToken else {
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
     * Attempts to refresh the current access token.
     *
     * - important: This method must be called within a lock.
     */
    internal func refreshAccessToken() throws {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        let newAccessToken = try doRefreshAccessToken()

        self.authInfo = self.authInfo?.refresh(withNewAccessToken: newAccessToken)

        do {
            try self.authInfo?.write(toStorage: &self.storage)
        } catch {
            throw StitchError.clientError(withClientErrorCode: .couldNotPersistAuthInfo)
        }
    }
}
