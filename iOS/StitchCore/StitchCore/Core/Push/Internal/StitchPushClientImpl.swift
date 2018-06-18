import Foundation
import MongoSwift
import StitchCoreSDK

internal final class StitchPushClientImpl: CoreStitchPushClientImpl, StitchPushClient {
    private let dispatcher: OperationDispatcher

    public init(requestClient: StitchAuthRequestClient,
                routes: StitchPushRoutes,
                name: String,
                dispatcher: OperationDispatcher) {
        self.dispatcher = dispatcher
        super.init(requestClient: requestClient, routes: routes, serviceName: name)
    }

    public func register(withRegistrationInfo registrationInfo: Document,
                         _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            try self.registerInternal(withRegistrationInfo: registrationInfo)
        }
    }

    public func deregister(_ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            try self.deregisterInternal()
        }
    }
}
