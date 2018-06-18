import Foundation

private final class HTTPNamedServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = HTTPServiceClient
    
    func client(withServiceClient serviceClient: StitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> HTTPServiceClient {
        return HTTPServiceClientImpl(
            withClient: CoreHTTPServiceClient.init(withService: serviceClient),
            withDispatcher: OperationDispatcher(withDispatchQueue: DispatchQueue.global())
        )
    }
}

public protocol HTTPServiceClient {
    /**
     * Executes the given `HTTPRequest`.
     *
     * - parameters:
     *     - request: The request to execute
     *     - completionHandler: The completion handler to call when the request is complete or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain the response to the request as an `HTTPResponse`.
     */
    func execute(request: HTTPRequest, _ completionHandler: @escaping (StitchResult<HTTPResponse>) -> Void)
}

public final class HTTPService {
    public static let sharedFactory = AnyNamedServiceClientFactory<HTTPServiceClient>(
        factory: HTTPNamedServiceClientFactory()
    )
}
