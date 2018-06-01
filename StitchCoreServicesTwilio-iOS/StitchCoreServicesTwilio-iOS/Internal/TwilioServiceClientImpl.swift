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
    
    /**
     * Sends an SMS/MMS message.
     *
     * @param to The number to send the message to.
     * @param from The number that the message is from.
     * @param body The body text of the message.
     * @param mediaUrl The URL of the media to send in an MMS.
     * @return A task that completes when the send is done.
     */
    public func sendMessage(to: String,
                            from: String,
                            body: String,
                            mediaURL: String? = nil,
                            completionHandler: @escaping (Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            try self.proxy.sendMessage(to: to,
                                       from: from,
                                       body: body,
                                       mediaURL: mediaURL)
        }
    }
}
