import Foundation
import MongoSwift
import StitchCoreSDK

public final class CoreAWSSESServiceClient {
    private let service: CoreStitchServiceClient
    
    public init(withService service: CoreStitchServiceClient) {
        self.service = service
    }
    
    public func sendEmail(toAddress: String,
                          fromAddress: String,
                          subject: String,
                          body: String) throws -> AWSSESSendResult {
        let args: Document = [
            "toAddress": toAddress,
            "fromAddress": fromAddress,
            "subject": subject,
            "body": body
        ]
        
        return try self.service.callFunctionInternal(withName: "send", withArgs: [args], withRequestTimeout: nil)
    }
}
