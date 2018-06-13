import Foundation
import StitchCore
import StitchCoreTwilioService
import StitchCoreSDK

private final class TwilioNamedServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = TwilioServiceClient
    
    func client(withServiceClient service: StitchServiceClient,
                withClientInfo client: StitchAppClientInfo) -> TwilioServiceClient {
        return TwilioServiceClientImpl(
            withClient: CoreTwilioServiceClient.init(withService: service),
            withDispatcher: OperationDispatcher(withDispatchQueue: DispatchQueue.global())
        )
    }
}

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
    func sendMessage(to: String,
                     from: String,
                     body: String,
                     mediaURL: String?,
                     _ completionHandler: @escaping (StitchResult<Void>) -> Void)
}

public final class TwilioService {
    public static let sharedFactory =
        AnyNamedServiceClientFactory<TwilioServiceClient>(factory: TwilioNamedServiceClientFactory())
}
