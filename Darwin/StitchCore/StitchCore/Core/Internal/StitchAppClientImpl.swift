import StitchCoreSDK
import MongoSwift
import Foundation

/**
 * The implementation of the `StitchAppClient` protocol.
 */
internal final class StitchAppClientImpl: StitchAppClient {

    // MARK: Properties

    /**
     * The client's underlying authentication state, publicly exposed as a `StitchAuth` interface.
     */
    public var auth: StitchAuth {
        return _auth
    }

    /**
     * The client's underlying push notification component.
     */
    public var push: StitchPush

    /**
     * The client's underlying authentication state.
     */
    private var _auth: StitchAuthImpl

    /**
     * The core `CoreStitchAppClient` used by the client to make function call requests.
     */
    private let coreClient: CoreStitchAppClient

    /**
     * The operation dispatcher used to dispatch asynchronous operations made by this client and its underlying
     * objects.
     */
    private let dispatcher: OperationDispatcher

    /**
     * A `StitchAppClientInfo` describing the basic properties of this app client.
     */
    internal let info: StitchAppClientInfo

    /**
     * The API routes on the Stitch server to perform actions for this particular app.
     */
    private let routes: StitchAppRoutes

    // MARK: Initializer

    /**
     * Initializes the app client with the provided configuration, and with an operation dispatcher that runs on
     * the provided `DispatchQueue` (the default global `DispatchQueue` by default).
     */
    public init(withClientAppID clientAppID: String,
                withConfig config: ImmutableStitchAppClientConfiguration,
                withDispatchQueue queue: DispatchQueue = DispatchQueue.global()) throws {
        self.dispatcher = OperationDispatcher.init(withDispatchQueue: queue)
        self.routes = StitchAppRoutes.init(clientAppID: clientAppID)
        self.info = StitchAppClientInfo(clientAppID: clientAppID,
                                        dataDirectory: config.dataDirectory,
                                        localAppName: config.localAppName,
                                        localAppVersion: config.localAppVersion
        )

        let internalAuth =
            try StitchAuthImpl.init(
                requestClient: StitchRequestClientImpl.init(baseURL: config.baseURL,
                                                            transport: config.transport,
                                                            defaultRequestTimeout: config.defaultRequestTimeout),
                authRoutes: self.routes.authRoutes,
                storage: config.storage,
                dispatcher: self.dispatcher,
                appInfo: self.info)

        self._auth = internalAuth
        self.push = StitchPushImpl.init(
            requestClient: self._auth,
            pushRoutes: self.routes.pushRoutes,
            dispatcher: self.dispatcher
        )
        self.coreClient = CoreStitchAppClient.init(authRequestClient: internalAuth, routes: routes)
    }

    // MARK: Services
    
    public func serviceClient(withServiceName serviceName: String) -> StitchServiceClient {
        return StitchServiceClientImpl.init(
            proxy: CoreStitchServiceClientImpl.init(
                requestClient: self._auth,
                routes: self.routes.serviceRoutes,
                serviceName: serviceName
            ),
            dispatcher: self.dispatcher
        )
    }

    public func serviceClient<T>(fromFactory factory: AnyNamedServiceClientFactory<T>,
                                 withName serviceName: String) -> T {
        return factory.client(
            forService: CoreStitchServiceClientImpl.init(requestClient: self._auth,
                                                         routes: self.routes.serviceRoutes,
                                                         serviceName: serviceName),
            withClientInfo: self.info
        )
    }

    public func serviceClient<T>(fromFactory factory: AnyNamedServiceClientFactory<T>) -> T {
        return factory.client(
            forService: CoreStitchServiceClientImpl.init(requestClient: self._auth,
                                                     routes: self.routes.serviceRoutes,
                                                     serviceName: nil),
            withClientInfo: self.info
        )
    }

    public func serviceClient<T>(fromFactory factory: AnyThrowingServiceClientFactory<T>) throws -> T {
        return try factory.client(
            forService: CoreStitchServiceClientImpl.init(requestClient: self._auth,
                                                         routes: self.routes.serviceRoutes,
                                                         serviceName: nil),
            withClientInfo: self.info
        )
    }

    // MARK: Functions

    public func callFunction(withName name: String,
                             withArgs args: [BsonValue],
                             _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.coreClient.callFunction(withName: name, withArgs: args)
        }
    }

    public func callFunction<T: Decodable>(withName name: String,
                                           withArgs args: [BsonValue],
                                           _ completionHandler: @escaping (StitchResult<T>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.coreClient.callFunction(withName: name,
                                                    withArgs: args)
        }
    }

    public func callFunction(withName name: String,
                             withArgs args: [BsonValue],
                             withRequestTimeout requestTimeout: TimeInterval,
                             _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.coreClient.callFunction(withName: name,
                                                    withArgs: args,
                                                    withRequestTimeout: requestTimeout
            )
        }
    }

    public func callFunction<T: Decodable>(withName name: String,
                                           withArgs args: [BsonValue],
                                           withRequestTimeout requestTimeout: TimeInterval,
                                           _ completionHandler: @escaping (StitchResult<T>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.coreClient.callFunction(withName: name,
                                                    withArgs: args,
                                                    withRequestTimeout: requestTimeout)
        }
    }
}
