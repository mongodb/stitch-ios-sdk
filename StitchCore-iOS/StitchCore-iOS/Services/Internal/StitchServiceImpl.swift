import StitchCore
import Foundation
import BSON

/**
 * The implementation of `StitchService`, which is capable of making requests to execute functions for a particular
 * service.
 */
internal final class StitchServiceImpl: CoreStitchServiceImpl, StitchService {
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
        super.init(requestClient: requestClient, routes: routes, name: name)
    }

    /**
     * Calls the function for this service with the provided name and arguments.
     *
     * - parameters:
     *     - withName: The name of the function to be called.
     *     - withArgs: The `BSONArray` of arguments to be provided to the function.
     *     - completionHandler: The completion handler to call when the function call is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - result: The result of the function call as an `Any`, or `nil` if the function call failed.
     *     - error: An error object that indicates why the function call failed, or `nil` if the function call was
     *              successful.
     *
     */
    public func callFunction<T: Codable>(withName name: String,
                             withArgs args: [BsonValue],
                             _ completionHandler: @escaping (T?, Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.callFunctionInternal(withName: name, withArgs: args)
        }
    }
}
