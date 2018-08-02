import Foundation
import StitchCore
import StitchCoreSDK
import StitchCoreAWSService

public final class AWSServiceClientImpl: AWSServiceClient {
    private let proxy: CoreAWSServiceClient
    private let dispatcher: OperationDispatcher
    
    internal init(withClient client: CoreAWSServiceClient,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = client
        self.dispatcher = dispatcher
    }
    
    public func execute(request: AWSRequest, _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            try self.proxy.execute(request: request)
        }
    }
    
    public func execute(request: AWSRequest, withRequestTimeout requestTimeout: TimeInterval, _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            try self.proxy.execute(request: request, withRequestTimeout: requestTimeout)
        }
    }
    
    public func execute<T>(request: AWSRequest, _ completionHandler: @escaping (StitchResult<T>) -> Void) where T : Decodable {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.execute(request: request)
        }
    }
    
    public func execute<T>(request: AWSRequest, withRequestTimeout requestTimeout: TimeInterval, _ completionHandler: @escaping (StitchResult<T>) -> Void) where T : Decodable {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.execute(request: request, withRequestTimeout: requestTimeout)
        }
    }
}
