import StitchCoreSDK
import Foundation
import MongoSwift

/**
 * The implementation of `StitchServiceClient`, which is capable of making requests to execute functions for a
 * particular service.
 */
internal final class StitchServiceClientImpl: StitchServiceClient {
    /**
     * The operation dispatcher used to dispatch asynchronous operations made by this service.
     */
    private let dispatcher: OperationDispatcher
    
    private let proxy: CoreStitchServiceClient

    /**
     * Initializes the service with the provided request client, service API routes, service name, and operation
     * dispatcher.
     */
    public init(proxy: CoreStitchServiceClient,
                dispatcher: OperationDispatcher) {
        self.proxy = proxy
        self.dispatcher = dispatcher
    }
    
    func callFunction(withName name: String,
                      withArgs args: [BsonValue],
                      _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            try self.proxy.callFunction(withName: name, withArgs: args, withRequestTimeout: nil)
        }
    }

    func callFunction(withName name: String,
                      withArgs args: [BsonValue],
                      withRequestTimeout requestTimeout: TimeInterval,
                      _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            try self.proxy.callFunction(withName: name, withArgs: args, withRequestTimeout: requestTimeout)
        }
    }
    
    public func callFunction<T: Decodable>(withName name: String,
                                           withArgs args: [BsonValue],
                                           _ completionHandler: @escaping (StitchResult<T>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.callFunction(withName: name, withArgs: args, withRequestTimeout: nil)
        }
    }

    public func callFunction<T: Decodable>(withName name: String,
                                           withArgs args: [BsonValue],
                                           withRequestTimeout requestTimeout: TimeInterval,
                                           _ completionHandler: @escaping (StitchResult<T>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.callFunction(withName: name, withArgs: args, withRequestTimeout: requestTimeout)
        }
    }
}
