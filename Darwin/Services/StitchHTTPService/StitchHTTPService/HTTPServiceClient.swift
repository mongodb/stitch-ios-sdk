import Foundation
import StitchCore
import StitchCoreHTTPService
import StitchCoreSDK

private final class HTTPNamedServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = HTTPServiceClient
    
    func client(withServiceClient serviceClient: CoreStitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> HTTPServiceClient {
        return HTTPServiceClientImpl(
            withClient: CoreHTTPServiceClient.init(withService: serviceClient),
            withDispatcher: OperationDispatcher(withDispatchQueue: DispatchQueue.global())
        )
    }
}

/**
 * Global factory const which can be used to create an `HTTPServiceClient` with a `StitchAppClient`. Pass into
 * `StitchAppClient.serviceClient(fromFactory:withName)` to get a `HTTPServiceClient.
 */
public let httpServiceClientFactory =
    AnyNamedServiceClientFactory<HTTPServiceClient>(factory: HTTPNamedServiceClientFactory())

/**
 * The HTTP service client, which can be used to perform HTTP requests via MongoDB Stitch.
 */
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
