import Foundation
import StitchCore
import StitchCore_iOS
import StitchCoreServicesTwilio

public final class TwilioServiceClientImpl: TwilioServiceClient {
    private let proxy: CoreTwilioServiceClient
    private let dispatcher: OperationDispatcher
    
    internal init(withClient client: CoreTwilioServiceClient,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = client
        self.dispatcher = dispatcher
    }

    public func sendMessage(to: String,
                            from: String,
                            body: String,
                            mediaURL: String? = nil,
                            _ completionHandler: @escaping (Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            try self.proxy.sendMessage(to: to,
                                       from: from,
                                       body: body,
                                       mediaURL: mediaURL)
        }
    }
}
