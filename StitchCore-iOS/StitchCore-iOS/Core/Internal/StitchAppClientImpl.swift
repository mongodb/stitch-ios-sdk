import StitchCore
import ExtendedJSON

/**
 * The implementation of the `StitchAppClient` protocol.
 */
internal final class StitchAppClientImpl: StitchAppClient {
    public var auth: StitchAuth {
        return _auth
    }
    private var _auth: StitchAuthImpl

    private let coreClient: CoreStitchAppClient

    private let dispatcher: OperationDispatcher
    private let info: StitchAppClientInfo
    private let routes: StitchAppRoutes

    public init(withConfig config: StitchAppClientConfiguration,
                withDispatchQueue queue: DispatchQueue = DispatchQueue.global()) throws {
        self.dispatcher = OperationDispatcher.init(withDispatchQueue: queue)
        self.routes = StitchAppRoutes.init(clientAppId: config.clientAppId)
        self.info = StitchAppClientInfo(clientAppId: config.clientAppId,
                                        dataDirectory: "", // STITCH-1346: make this non-empty
                                        localAppName: config.localAppName,
                                        localAppVersion: config.localAppVersion
        )

        let internalAuth =
            try StitchAuthImpl.init(requestClient: StitchRequestClientImpl.init(baseURL: config.baseURL,
                                                                                transport: config.transport),
                                     authRoutes: self.routes.authRoutes,
                                     storage: config.storage,
                                     dispatcher: self.dispatcher,
                                     appInfo: self.info)

        self._auth = internalAuth
        self.coreClient = CoreStitchAppClient.init(authRequestClient: internalAuth, routes: routes)
    }

    public func serviceClient<T>(forService serviceClientProvider: AnyNamedServiceClientProvider<T>,
                                 withName serviceName: String) -> T {
        return serviceClientProvider.client(
            forService: StitchServiceImpl.init(requestClient: self._auth,
                                               routes: self.routes.serviceRoutes,
                                               name: serviceName, dispatcher: self.dispatcher),
            withClient: self.info
        )
    }

    public func serviceClient<T>(forService serviceClientProvider: AnyServiceClientProvider<T>) -> T {
        return serviceClientProvider.client(
            forService: StitchServiceImpl.init(requestClient: self._auth,
                                               routes: self.routes.serviceRoutes,
                                               name: "", dispatcher: self.dispatcher),
            withClient: self.info
        )
    }

    public func callFunction(withName name: String,
                             withArgs args: BSONArray,
                             _ completionHandler: @escaping (Any?, Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.coreClient.callFunctionInternal(withName: name, withArgs: args)
        }
    }
}
