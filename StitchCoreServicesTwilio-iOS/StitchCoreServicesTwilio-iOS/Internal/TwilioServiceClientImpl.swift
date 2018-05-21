import Foundation
import StitchCore
import StitchCore_iOS
import StitchCoreServicesTwilio

public final class TwilioServiceClientImpl: CoreTwilioServiceClient, TwilioServiceClient {
    private let dispatcher: OperationDispatcher
    
    internal init(withService service: StitchService,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.dispatcher = dispatcher
        super.init(withService: service)
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
            try self.sendMessageInternal(to: to,
                                         from: from,
                                         body: body,
                                         mediaURL: mediaURL)
        }
    }
}
