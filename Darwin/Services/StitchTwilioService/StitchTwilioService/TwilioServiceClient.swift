import Foundation
import StitchCore
import StitchCoreTwilioService
import StitchCoreSDK

private final class TwilioNamedServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = TwilioServiceClient
    
    func client(withServiceClient service: CoreStitchServiceClient,
                withClientInfo client: StitchAppClientInfo) -> TwilioServiceClient {
        return TwilioServiceClientImpl(
            withClient: CoreTwilioServiceClient.init(withService: service),
            withDispatcher: OperationDispatcher(withDispatchQueue: DispatchQueue.global())
        )
    }
}

/**
 * Global factory const which can be used to create a `TwilioServiceClient` with a `StitchAppClient`. Pass into
 * `StitchAppClient.serviceClient(fromFactory:withName)` to get a `TwilioServiceClient.
 */
public let twilioServiceClientFactory =
    AnyNamedServiceClientFactory<TwilioServiceClient>(factory: TwilioNamedServiceClientFactory())

/**
 * The Twilio service client, which can be used to send text messages with Twilio via MongoDB Stitch.
 */
public protocol TwilioServiceClient {
    /**
     * Sends an SMS/MMS message.
     *
     * - parameters:
     *     - to: The number to send the message to.
     *     - from: The number that the message is from.
     *     - body: The body text of the message.
     *     - completionHandler: The completion handler to call when the message is sent or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func sendMessage(to: String, from: String, body: String, mediaURL: String?, _ completionHandler: @escaping (StitchResult<Void>) -> Void)
}
