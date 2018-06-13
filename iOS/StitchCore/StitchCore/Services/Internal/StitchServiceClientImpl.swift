import StitchCoreSDK
import Foundation
import MongoSwift

/**
 * The implementation of `StitchServiceClient`, which is capable of making requests to execute functions for a
 * particular service.
 */
internal final class StitchServiceClientImpl: CoreStitchServiceClientImpl, StitchServiceClient {
    /**
     * The operation dispatcher used to dispatch asynchronous operations made by this service.
     */
    private let dispatcher: OperationDispatcher

    /**
     * Initializes the service with the provided request client, service API routes, service name, and operation
     * dispatcher.
     */
    public init(requestClient: StitchAuthRequestClient,
                routes: StitchServiceRoutes,
                name: String,
                dispatcher: OperationDispatcher) {
        self.dispatcher = dispatcher
        super.init(requestClient: requestClient, routes: routes, serviceName: name)
    }

    /**
     * Calls the MongoDB Stitch function with the provided name and arguments. Also accepts a timeout. Use this for
     * function that may run longer than the client-wide default timeout (15 seconds by default).
     *
     * - parameters:
     *     - withName: The name of the Stitch function to be called.
     *     - withArgs: The `BSONArray` of arguments to be provided to the function.
     *     - completionHandler: The completion handler to call when the function call is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *
     */
    func callFunction(withName name: String,
                      withArgs args: [BsonValue],
                      withRequestTimeout requestTimeout: TimeInterval,
                      _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            try self.callFunctionInternal(withName: name, withArgs: args, withRequestTimeout: requestTimeout)
        }
    }

    /**
     * Calls the MongoDB Stitch function with the provided name and arguments, and decodes the result of the function
     * into a `Decodable` type as specified by the `T` type parameter. Also accepts a timeout. Use this for functions
     * that may run longer than the client-wide default timeout (15 seconds by default).
     *
     * - parameters:
     *     - withName: The name of the Stitch function to be called.
     *     - withArgs: The `BSONArray` of arguments to be provided to the function.
     *     - withRequestTimeout: The number of seconds the client should wait for a response from the server before
     *                           failing with an error.
     *     - completionHandler: The completion handler to call when the function call is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain a `T` representing the decoded result of the
     *                          function call.
     */
    public func callFunction<T: Decodable>(withName name: String,
                                           withArgs args: [BsonValue],
                                           withRequestTimeout requestTimeout: TimeInterval,
                                           _ completionHandler: @escaping (StitchResult<T>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.callFunctionInternal(withName: name, withArgs: args, withRequestTimeout: requestTimeout)
        }
    }
}
