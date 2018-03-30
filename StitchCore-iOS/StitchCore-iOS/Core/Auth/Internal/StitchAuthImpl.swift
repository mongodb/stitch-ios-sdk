import ExtendedJSON
import StitchCore
import Foundation

/**
 * The implementation of `StitchAuth`, which holds and manages the authentication state of a Stitch client.
 */
internal final class StitchAuthImpl: CoreStitchAuth<StitchUserImpl>, StitchAuth {

    // MARK: Private Properties

    /**
     * The operation dispatcher used to dispatch asynchronous operations made by this client and its underlying
     * objects.
     */
    private let dispatcher: OperationDispatcher

    /**
     * A `StitchAppClientInfo` describing the basic properties of the app client holding this `StitchAuthImpl.
     */
    private let appInfo: StitchAppClientInfo

    /**
     * A struct for holding weak references to `StitchAuthDelegate`.
     */
    private struct DelegateWeakRef {
        weak var value: StitchAuthDelegate?
        init(value: StitchAuthDelegate) {
            self.value = value
        }
    }

    /**
     * An array of weak references to `StitchAuthDelegate`, each of which will be notified when authentication events
     * occur.
     */
    private var delegates: [DelegateWeakRef] = []

    /**
     * Initializes this `StitchAuthImpl` with a request client, authentication API routes, a `Storage` for persisting
     * authentication information, an `OperationDispatcher` for dispatching asynchronous operations, and a
     * `StitchAppClientInfo` containing information about the app client that will hold this `StitchAuthImpl`.
     */
    public init(
        requestClient: StitchRequestClient,
        authRoutes: StitchAuthRoutes,
        storage: Storage,
        dispatcher: OperationDispatcher,
        appInfo: StitchAppClientInfo) throws {

        self.dispatcher = dispatcher
        self.appInfo = appInfo
        try super.init(requestClient: requestClient, authRoutes: authRoutes, storage: storage)
    }

    // MARK: Authentication Provider Clients

    /**
     * Retrieves the authentication provider client associated with the authentication provider type specified in the
     * argument.
     *
     * - parameters:
     *     - forProvider: The authentication provider conforming to `AuthProviderClientSupplier` which will provide the
     *                    client for this authentication provider. Use the `clientProvider` field of the desired
     *                    authentication provider class.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `forProvider` parameter.
     */
    public func providerClient<Provider>(forProvider provider: Provider)
        -> Provider.Client where Provider: AuthProviderClientSupplier {
        return provider.client(withRequestClient: self.requestClient,
                               withRoutes: self.authRoutes,
                               withDispatcher: self.dispatcher)
    }

    /**
     * Retrieves the authentication provider client associated with the authentication provider with the specified name
     * and type.
     *
     * - parameters:
     *     - forProvider: The authentication provider conforming to `NamedAuthProviderClientSupplier` which will
     *                    provide the client for this authentication provider. Use the `NamedClientProvider` field of
     *                    the desired authentication provider class.
     *     - withName: The name of the authentication provider as defined in the MongoDB Stitch application.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `forProvider` parameter.
     */
    public func providerClient<Provider>(forProvider provider: Provider, withName name: String)
        -> Provider.Client where Provider: NamedAuthProviderClientSupplier {
        return provider.client(forProviderName: name,
                               withRequestClient: self.requestClient,
                               withRoutes: self.authRoutes,
                               withDispatcher: self.dispatcher)
    }

    // MARK: Authentication Actions

    /**
     * Authenticates the client as a MongoDB Stitch user using the provided `StitchCredential`.
     *
     * - parameters:
     *     - withCredential: The `StitchCredential` used to authenticate the
     *                       client. Credentials can be retrieved from an
     *                       authentication provider client, which is retrieved
     *                       using the `providerClient` method.
     *     - completionHandler: The completion handler to call when the login is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - user: A `StitchUser` object representing the user that the client is now authenticated as, or `nil` if the
     *             login failed.
     *     - error: An error object that indicates why the login failed, or `nil` if the login was successful.
     */
    public func login(withCredential credential: StitchCredential,
                      _ completionHandler: @escaping ((StitchUser?, Error?) -> Void)) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.loginWithCredentialBlocking(withCredential: credential)
        }
    }

    /**
     * Logs out the currently authenticated user, and clears any persisted
     * authentication information.
     *
     * - parameters:
     *     - completionHandler: The completion handler to call when the logout is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - error: An error object that indicates why the logout failed, or `nil` if the logout was successful.
     */
    internal func link(withCredential credential: StitchCredential,
                       withUser user: StitchUserImpl,
                       _ completionHandler: @escaping ((StitchUser?, Error?) -> Void)) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.linkUserWithCredentialBlocking(withUser: user, withCredential: credential)
        }
    }

    public func logout(_ completionHandler: @escaping ((Error?) -> Void)) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            try self.logoutBlocking()
        }
    }

    // MARK: Computed Properties

    /**
     * A user factory capable of producing `StitchUserImpl` objects that represent the user currently authenticated
     * by this `StitchAuthImpl`
     */
    public final override var userFactory: AnyStitchUserFactory<StitchUserImpl> {
        return AnyStitchUserFactory.init(stitchUserFactory: StitchUserFactoryImpl.init(withAuth: self))
    }

    /**
     * A `StitchUser` object representing the user that the client is currently authenticated as.
     * `nil` if the client is not currently authenticated.
     */
    public final var currentUser: StitchUser? {
        return self.user
    }

    /**
     * A BSON document containing information about the current device such as device ID, local app name and version,
     * platform and platform version, and the current version of the Stitch SDK.
     */
    public final override var deviceInfo: Document {
        var info = Document.init()

        if self.hasDeviceId, let deviceId = self.deviceId {
            info[DeviceField.deviceId.rawValue] = deviceId
        }

        info[DeviceField.appId.rawValue] = self.appInfo.localAppName
        info[DeviceField.appVersion.rawValue] = self.appInfo.localAppVersion
        info[DeviceField.platform.rawValue] = UIDevice.current.systemName
        info[DeviceField.platformVersion.rawValue] = UIDevice.current.systemVersion
        info[DeviceField.sdkVersion.rawValue] = Stitch.sdkVersion

        return info
    }

    // MARK: Observer Delegates

    /**
     * Registers a `StitchAuthDelegate` with the client. The `StitchAuthDelegate`'s `onAuthEvent(:fromAuth)`
     * method will be called with this `StitchAuth` as the argument whenever this client is authenticated
     * or is logged out.
     *
     * - important: StitchAuthDelegates registered here are stored as `weak` references, meaning that if there are no
     *              more strong references to a provided delegate, its `onAuthEvent(:fromAuth)` method will no longer
     *              be called on authentication events.
     * - parameters:
     *     - authDelegate: A class conforming to `StitchAuthDelegate`, whose `onAuthEvent(:fromAuth)` method should be
     *                     called whenever this client experiences an authentication event.
     */
    public func add(authDelegate: StitchAuthDelegate) {
        // swiftlint:disable force_try
        try! sync(self) {
            // swiftlint:enable force_try
            self.delegates.append(DelegateWeakRef(value: authDelegate))
        }

        // Trigger the onUserLoggedIn event in case some event happens and
        // this caller would miss out on this event other wise.
        dispatcher.queue.async {
            authDelegate.onAuthEvent(fromAuth: self)
        }
    }

    /**
     * Calls the `onAuthEvent` method of each registered `StitchAuthDelegate`.
     *
     * - important: This is not meant to be invoked directly in this class. The `CoreStitchAuth` from which this
     *              class inherits will call this method when appropraite.
     */
    public final override func onAuthEvent() {
        self.delegates.enumerated().reversed().forEach { idx, delegateRef in
            guard let delegate = delegateRef.value else {
                self.delegates.remove(at: idx)
                return
            }

            dispatcher.queue.async {
                delegate.onAuthEvent(fromAuth: self)
            }
        }
    }
}
