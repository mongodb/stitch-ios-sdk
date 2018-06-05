import Foundation
import StitchCore_iOS
import StitchCoreServicesHttp

public final class HttpServiceClientImpl: HttpServiceClient {
    private let proxy: CoreHttpServiceClient
    private let dispatcher: OperationDispatcher
    
    internal init(withClient client: CoreHttpServiceClient,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = client
        self.dispatcher = dispatcher
    }
    
    public func execute(request: HttpRequest, _ completionHandler: @escaping (HttpResponse?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.execute(request: request)
        }
    }
    
    public func execute(request: HttpRequest,
                        timeout: TimeInterval,
                        _ completionHandler: @escaping (HttpResponse?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.execute(request: request, timeout: timeout)
        }
    }
}
