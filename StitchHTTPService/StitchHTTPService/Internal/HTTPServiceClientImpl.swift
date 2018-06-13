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
    
    public func execute(request: HTTPRequest, _ completionHandler: @escaping (StitchResult<HTTPResponse>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.execute(request: request)
        }
    }
}
