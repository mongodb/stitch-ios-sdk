import Foundation

/**
 * The result of an AWS SES send request.
 */
public struct AwsSesSendResult: Decodable {
    public enum CodingKeys: String, CodingKey {
        case messageId
    }
    
    /**
     * The id of the sent message.
     */
    public let messageId: String
}
