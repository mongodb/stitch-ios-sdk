import Foundation
import StitchCore
import StitchCoreHTTPService
import StitchCoreSDK

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
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func execute(request: HTTPRequest, _ completionHandler: @escaping (_ response: HTTPResponse?, _ error: Error?) -> Void)
    
    /**
     * Executes the given `HTTPRequest`. A timeout can be specified if the operation is expected to
     * take longer than the default timeout configured for the Stitch app client.
     *
     * - parameters:
     *     - request: The request to execute
     *     - completionHandler: The completion handler to call when the request is complete or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func execute(request: HTTPRequest, timeout: TimeInterval, _ completionHandler: @escaping (_ response: HTTPResponse?, _ error: Error?) -> Void)
}

public final class HTTPService {
    public static let sharedFactory = AnyNamedServiceClientFactory<HTTPServiceClient>(
        factory: HTTPNamedServiceClientFactory()
    )
}
