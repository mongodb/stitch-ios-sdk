import Foundation

/**
 * The result of an AWS SES send request.
 */
public struct AWSSESSendResult: Decodable {
    /**
     * The id of the sent message.
     */
    public let messageID: String
    
    internal enum CodingKeys: String, CodingKey {
        case messageID = "messageId"
    }
}
