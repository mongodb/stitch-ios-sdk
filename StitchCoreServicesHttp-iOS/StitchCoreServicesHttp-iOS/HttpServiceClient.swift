import Foundation
import StitchCore
import StitchCoreServicesHttp
import StitchCore_iOS

private final class HttpNamedServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = HttpServiceClient
    
    func client(withServiceClient serviceClient: StitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> HttpServiceClient {
        return HttpServiceClientImpl(
            withClient: CoreHttpServiceClient.init(withService: serviceClient),
            withDispatcher: OperationDispatcher(withDispatchQueue: DispatchQueue.global())
        )
    }
}

public protocol HttpServiceClient {
    /**
     * Executes the given `HttpRequest`.
     *
     * - parameters:
     *     - request: The request to execute
     *     - completionHandler: The completion handler to call when the request is complete or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func execute(request: HttpRequest, _ completionHandler: @escaping (HttpResponse?, Error?) -> Void)
    
    /**
     * Executes the given `HttpRequest`. A timeout can be specified if the operation is expected to
     * take longer than the default timeout configured for the Stitch app client.
     *
     * - parameters:
     *     - request: The request to execute
     *     - completionHandler: The completion handler to call when the request is complete or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func execute(request: HttpRequest, timeout: TimeInterval, _ completionHandler: @escaping (HttpResponse?, Error?) -> Void)
}

public final class HttpService {
    public static let sharedFactory = AnyNamedServiceClientFactory<HttpServiceClient>(
        factory: HttpNamedServiceClientFactory()
    )
}
