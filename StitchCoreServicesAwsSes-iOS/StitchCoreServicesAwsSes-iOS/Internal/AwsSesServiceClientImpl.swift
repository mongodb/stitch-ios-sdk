import Foundation
import StitchCore
import StitchCore_iOS
import StitchCoreServicesAwsSes

public final class AwsSesServiceClientImpl: AwsSesServiceClient {
    private let proxy: CoreAwsSesServiceClient
    private let dispatcher: OperationDispatcher
    
    internal init(withClient client: CoreAwsSesServiceClient,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = client
        self.dispatcher = dispatcher
    }
    
    public func sendEmail(to: String,
                          from: String,
                          subject: String,
                          body: String,
                          _ completionHandler: @escaping (AwsSesSendResult?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.sendEmail(toAddress: to, fromAddress: from, subject: subject, body: body)
        }
    }
}
