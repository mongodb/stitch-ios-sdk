import Foundation
import StitchCore
import StitchCoreAWSSESService
import StitchCoreSDK

private final class AWSSESNamedServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = AWSSESServiceClient
    
    func client(withServiceClient service: StitchServiceClient,
                withClientInfo client: StitchAppClientInfo) -> AWSSESServiceClient {
        return AWSSESServiceClientImpl(
            withClient: CoreAWSSESServiceClient.init(withService: service),
            withDispatcher: OperationDispatcher(withDispatchQueue: DispatchQueue.global())
        )
    }
}

public protocol AWSSESServiceClient {
    /**
     * Sends an email.
     *
     * - parameters:
     *     - to: the email address to send the email to.
     *     - from: the email address to send the email from.
     *     - subject: the subject of the email.
     *     - body: the body text of the email.
     *     - completionHandler: The completion handler to call when the email is sent or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func sendEmail(to: String,
                   from: String,
                   subject: String,
                   body: String,
                   _ completionHandler: @escaping (AWSSESSendResult?, Error?) -> Void)
}

public final class AWSSESService {
    public static let sharedFactory =
        AnyNamedServiceClientFactory<AWSSESServiceClient>(factory: AWSSESNamedServiceClientFactory())
}
