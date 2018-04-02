import ExtendedJSON
import StitchCore
import Foundation

internal final class StitchAuthImpl: CoreStitchAuth<StitchUserImpl>, StitchAuth {
    private let dispatcher: OperationDispatcher
    private let appInfo: StitchAppClientInfo

    private struct DelegateWeakRef {
        weak var value: StitchAuthDelegate?
        init(value: StitchAuthDelegate) {
            self.value = value
        }
    }
    private var delegates: [DelegateWeakRef] = []

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

    public func providerClient<Provider>(forProvider provider: Provider)
        -> Provider.Client where Provider: AuthProviderClientSupplier {
        return provider.client(withRequestClient: self.requestClient,
                               withRoutes: self.authRoutes,
                               withDispatcher: self.dispatcher)
    }

    public func providerClient<Provider>(forProvider provider: Provider, withName name: String)
        -> Provider.Client where Provider: NamedAuthProviderClientSupplier {
        return provider.client(forProviderName: name,
                               withRequestClient: self.requestClient,
                               withRoutes: self.authRoutes,
                               withDispatcher: self.dispatcher)
    }

    public func login(withCredential credential: StitchCredential,
                      _ completionHandler: @escaping ((StitchUser?, Error?) -> Void)) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.loginWithCredentialBlocking(withCredential: credential)
        }
    }

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

    public final override var userFactory: AnyStitchUserFactory<StitchUserImpl> {
        return AnyStitchUserFactory.init(stitchUserFactory: StitchUserFactoryImpl.init(withAuth: self))
    }

    public final var currentUser: StitchUser? {
        return self.user
    }

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

    // Not meant to be invoked directly.
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
