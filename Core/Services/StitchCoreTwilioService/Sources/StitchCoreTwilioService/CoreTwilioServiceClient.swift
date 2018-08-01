import Foundation
import MongoSwift
import StitchCoreSDK

/// :nodoc:
public final class CoreTwilioServiceClient {
    
    private let service: CoreStitchServiceClient
    
    public init(withService service: CoreStitchServiceClient) {
        self.service = service
    }
    
    public func sendMessage(to: String,
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
        
        try self.service.callFunction(withName: "send", withArgs: [args], withRequestTimeout: nil)
    }
}
