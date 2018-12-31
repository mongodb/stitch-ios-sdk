import Foundation
import StitchCore
import StitchCoreFCMService

internal final class FCMServicePushClientImpl: FCMServicePushClient {
    private let proxy: CoreFCMServicePushClient
    private let dispatcher: OperationDispatcher

    internal init(withServicePushClient client: CoreFCMServicePushClient,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = client
        self.dispatcher = dispatcher
    }

    func register(withRegistrationToken token: String, _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            try self.proxy.register(withRegistrationToken: token)
        }
    }

    func deregister(_ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            try self.proxy.deregister()
        }
    }
}
