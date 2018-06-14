import Foundation

/**
 * The details of an individual message failure inside an FCM send message request.
 */
public struct FCMSendMessageResultFailureDetail: Decodable, Equatable {
    /**
     * The index corresponding to the target.
     */
    public let index: Int64
    /**
     * The error that occurred.
     */
    public let error: String
    
    /**
     * The user ID that could not be sent a message to, if applicable.
     */
    public let userID: String?
    
    internal enum CodingKeys: String, CodingKey {
        case index, error, userID = "userId"
    }
}
