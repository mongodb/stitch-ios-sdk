import Foundation
import StitchCore
import StitchCoreFCMService

internal final class FCMServiceClientImpl: FCMServiceClient {
    private let proxy: CoreFCMServiceClient
    private let dispatcher: OperationDispatcher

    internal init(withClient client: CoreFCMServiceClient,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = client
        self.dispatcher = dispatcher
    }

    func sendMessage(to target: String,
                     withRequest request: FCMSendMessageRequest,
                     _ completionHandler: @escaping (StitchResult<FCMSendMessageResult>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.sendMessage(to: target, withRequest: request)
        }
    }

    func sendMessage(toUserIDs userIDs: [String],
                     withRequest request: FCMSendMessageRequest,
                     _ completionHandler: @escaping (StitchResult<FCMSendMessageResult>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.sendMessage(toUserIDs: userIDs, withRequest: request)
        }
    }

    func sendMessage(toRegistrationTokens registrationTokens: [String],
                     withRequest request: FCMSendMessageRequest,
                     _ completionHandler: @escaping (StitchResult<FCMSendMessageResult>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.sendMessage(toRegistrationTokens: registrationTokens, withRequest: request)
        }
    }
}
