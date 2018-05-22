import Foundation
import MongoSwift
import StitchCore

open class CoreTwilioServiceClient {
    
    private let service: CoreStitchService
    
    public init(withService service: CoreStitchService) {
        self.service = service
    }
    
    public func sendMessageInternal(to: String,
                                    from: String,
                                    body: String,
                                    mediaURL: String? = nil) throws {
        var args: Document = [
            "to": to,
            "from": from,
            "body": body
        ]

        if mediaURL != nil {
            args["mediaUrl"] = mediaURL
        }
        
        let _ =
        try self.service.callFunctionInternal(withName: "send", withArgs: [args], withRequestTimeout: nil)
    }
}
