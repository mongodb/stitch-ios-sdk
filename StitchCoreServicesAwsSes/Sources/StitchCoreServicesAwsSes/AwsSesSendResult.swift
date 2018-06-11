import Foundation

/**
 * The result of an AWS SES send request.
 */
public struct AwsSesSendResult: Decodable {
    /**
     * The id of the sent message.
     */
    public let messageID: String
    
    public enum CodingKeys: String, CodingKey {
        case messageID = "messageId"
    }
}
