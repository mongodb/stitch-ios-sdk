import Foundation
import StitchCore
import StitchCoreHTTPService

public final class HTTPServiceClientImpl: HTTPServiceClient {
    private let proxy: CoreHTTPServiceClient
    private let dispatcher: OperationDispatcher
    
    internal init(withClient client: CoreHTTPServiceClient,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = client
        self.dispatcher = dispatcher
    }
    
    public func execute(request: HTTPRequest, _ completionHandler: @escaping (HTTPResponse?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.execute(request: request)
        }
    }
    
    public func execute(request: HTTPRequest,
                        timeout: TimeInterval,
                        _ completionHandler: @escaping (HTTPResponse?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.execute(request: request, timeout: timeout)
        }
    }
}
