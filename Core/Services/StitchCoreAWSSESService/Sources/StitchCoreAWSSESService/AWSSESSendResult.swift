import Foundation

/**
 * The result of an AWS SES send request. (Deprecated)
 */
@available(*, deprecated, message: "Use the generic AWS service instead")
public struct AWSSESSendResult: Decodable {
    /**
     * The id of the sent message.
     */
    public let messageID: String
    
    internal enum CodingKeys: String, CodingKey {
        case messageID = "messageId"
    }
}
