import Foundation
import StitchCore
import StitchCoreSDK
import StitchCoreAWSSESService

public final class AWSSESServiceClientImpl: AWSSESServiceClient {
    private let proxy: CoreAWSSESServiceClient
    private let dispatcher: OperationDispatcher
    
    internal init(withClient client: CoreAWSSESServiceClient,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = client
        self.dispatcher = dispatcher
    }
    
    public func sendEmail(to: String,
                          from: String,
                          subject: String,
                          body: String,
                          _ completionHandler: @escaping (AWSSESSendResult?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.sendEmail(toAddress: to, fromAddress: from, subject: subject, body: body)
        }
    }
}
