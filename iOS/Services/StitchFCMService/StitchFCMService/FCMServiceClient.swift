import Foundation
import StitchCore
import StitchCoreFCMService

private final class FCMNamedServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = FCMServiceClient
    
    func client(withServiceClient serviceClient: StitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> FCMServiceClient {
        return FCMServiceClientImpl.init(
            withClient: CoreFCMServiceClient(withServiceClient: serviceClient),
            withDispatcher: OperationDispatcher(withDispatchQueue: DispatchQueue.global())
        )
    }
}

/**
 * Global factory const which can be used to create a `FCMServiceClient` with a `StitchAppClient`. Pass into
 * `StitchAppClient.serviceClient(fromFactory:withName)` to get an `FCMServiceClient.
 */
public let fcmServiceClientFactory =
    AnyNamedServiceClientFactory<FCMServiceClient>(factory: FCMNamedServiceClientFactory())

/**
 * The FCM service client, which can be used to send push notifications to other users via MongoDB Stitch.
 */
public protocol FCMServiceClient {
    
    /**
     * Sends an FCM message to the given target with the given request payload.
     *
     * - parameters:
     *     - to: the target to send a message to.
     *     - withRequest: the details of the message.
     *     - completionHandler: The completion handler to call when the message is sent or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain the result of the send message request as an
     *                          `FCMSendMessageRequest`.
     */
    func sendMessage(to target: String, withRequest request: FCMSendMessageRequest, _ completionHandler: @escaping (StitchResult<FCMSendMessageResult>) -> Void)
    
    /**
     * Sends an FCM message to the given set of Stitch users with the given request payload.
     *
     * - parameters:
     *     - toUserIDs: the Stitch users to send a message to.
     *     - withRequest: the details of the message.
     *     - completionHandler: The completion handler to call when the message is sent or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain the result of the send message request as an
     *                          `FCMSendMessageRequest`.
     */
    func sendMessage(toUserIDs userIDs: [String], withRequest request: FCMSendMessageRequest, _ completionHandler: @escaping (StitchResult<FCMSendMessageResult>) -> Void)
    
    /**
     * Sends an FCM message to the given set of registration tokens with the given request payload.
     *
     * - parameters:
     *     - toRegistrationTokens the devices to send a message to.
     *     - withRequest: the details of the message.
     *     - completionHandler: The completion handler to call when the message is sent or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain the result of the send message request as an
     *                          `FCMSendMessageRequest`.
     */
    func sendMessage(toRegistrationTokens registrationTokens: [String], withRequest request: FCMSendMessageRequest, _ completionHandler: @escaping (StitchResult<FCMSendMessageResult>) -> Void)
}
