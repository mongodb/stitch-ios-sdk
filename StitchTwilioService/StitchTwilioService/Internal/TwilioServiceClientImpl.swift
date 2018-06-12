import Foundation
import StitchCore
import StitchCoreSDK
import StitchCoreTwilioService

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
                            _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            try self.proxy.sendMessage(to: to,
                                       from: from,
                                       body: body,
                                       mediaURL: mediaURL)
        }
    }
}
