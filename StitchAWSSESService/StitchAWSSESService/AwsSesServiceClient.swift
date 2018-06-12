import Foundation
import StitchAWSSESService
import StitchCore
import StitchCoreSDK

private final class AwsSesNamedServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = AwsSesServiceClient
    
    func client(withServiceClient service: StitchServiceClient,
                withClientInfo client: StitchAppClientInfo) -> AwsSesServiceClient {
        return AwsSesServiceClientImpl(
            withClient: CoreAwsSesServiceClient.init(withService: service),
            withDispatcher: OperationDispatcher(withDispatchQueue: DispatchQueue.global())
        )
    }
}

public protocol AwsSesServiceClient {
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
                   _ completionHandler: @escaping (AwsSesSendResult?, Error?) -> Void)
}

public final class AwsSesService {
    public static let sharedFactory =
        AnyNamedServiceClientFactory<AwsSesServiceClient>(factory: AwsSesNamedServiceClientFactory())
}
