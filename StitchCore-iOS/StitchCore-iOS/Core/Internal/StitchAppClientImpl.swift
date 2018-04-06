import StitchCore
import ExtendedJSON

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
    private let info: StitchAppClientInfo

    /**
     * The API routes on the Stitch server to perform actions for this particular app.
     */
    private let routes: StitchAppRoutes

    // MARK: Initializer

    /**
     * Initializes the app client with the provided configuration, and with an operation dispatcher that runs on
     * the provided `DispatchQueue` (the default global `DispatchQueue` by default).
     */
    public init(withConfig config: StitchAppClientConfiguration,
                withDispatchQueue queue: DispatchQueue = DispatchQueue.global()) throws {
        self.dispatcher = OperationDispatcher.init(withDispatchQueue: queue)
        self.routes = StitchAppRoutes.init(clientAppId: config.clientAppId)
        self.info = StitchAppClientInfo(clientAppId: config.clientAppId,
                                        dataDirectory: config.dataDirectory, // STITCH-1346: make this non-empty
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

    // MARK: Services

    /**
     * Retrieves the service client associated with the Stitch service with the specified name and type.
     *
     * - parameters:
     *     - forProvider: An `AnyNamedServiceClientProvider` object which contains a `NamedServiceClientProvider`
     *                    class which will provide the client for this service.
     *     - withName: The name of the service as defined in the MongoDB Stitch application.
     * - returns: a service client whose type is determined by the `T` type parameter of the
     *            `AnyNamedServiceClientProvider` passed in the `forProvider` parameter.
     */
    public func serviceClient<T>(forService serviceClientProvider: AnyNamedServiceClientProvider<T>,
                                 withName serviceName: String) -> T {
        return serviceClientProvider.client(
            forService: StitchServiceImpl.init(requestClient: self._auth,
                                               routes: self.routes.serviceRoutes,
                                               name: serviceName, dispatcher: self.dispatcher),
            withClient: self.info
        )
    }

    /**
     * Retrieves the service client associated with the service type specified in the argument.
     *
     * - parameters:
     *     - forProvider: An `AnyServiceClientProvider` object which contains a `ServiceClientProvider`
     *                    class which will provide the client for this service.
     * - returns: a service client whose type is determined by the `T` type parameter of the `AnyServiceClientProvider`
     *            passed in the `forProvider` parameter.
     */
    public func serviceClient<T>(forService serviceClientProvider: AnyServiceClientProvider<T>) -> T {
        return serviceClientProvider.client(
            forService: StitchServiceImpl.init(requestClient: self._auth,
                                               routes: self.routes.serviceRoutes,
                                               name: "", dispatcher: self.dispatcher),
            withClient: self.info
        )
    }

    // MARK: Functions

    /**
     * Calls the MongoDB Stitch function with the provided name and arguments.
     *
     * - parameters:
     *     - withName: The name of the Stitch function to be called.
     *     - withArgs: The `BSONArray` of arguments to be provided to the function.
     *     - completionHandler: The completion handler to call when the function call is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - result: The result of the function call as an `Any`, or `nil` if the function call failed.
     *     - error: An error object that indicates why the function call failed, or `nil` if the function call was
     *              successful.
     *
     */
    public func callFunction(withName name: String,
                             withArgs args: BSONArray,
                             _ completionHandler: @escaping (Any?, Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.coreClient.callFunctionInternal(withName: name, withArgs: args)
        }
    }
}
