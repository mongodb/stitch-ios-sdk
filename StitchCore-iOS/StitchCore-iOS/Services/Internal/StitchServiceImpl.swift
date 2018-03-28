import StitchCore
import Foundation
import ExtendedJSON

internal final class StitchServiceImpl: CoreStitchService, StitchService {
    private let dispatcher: OperationDispatcher

    public init(requestClient: StitchAuthRequestClient,
                routes: StitchServiceRoutes,
                name: String,
                dispatcher: OperationDispatcher) {
        self.dispatcher = dispatcher
        super.init(requestClient: requestClient, routes: routes, name: name)
    }

    public func callFunction(withName name: String,
                             withArgs args: BSONArray,
                             _ completionHandler: @escaping (Any?, Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.callFunctionInternal(withName: name, withArgs: args)
        }
    }
}
