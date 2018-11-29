import Foundation

/**
 * The result of an FCM send message request.
 */
public struct FCMSendMessageResult: Decodable {
    /**
     * The number of messages successfully sent.
     */
    public let successes: Int64

    /**
     * The number of messages that failed to be sent.
     */
    public let failures: Int64

    /**
     * The details of each failure, if there were failures.
     */
    public let failureDetails: [FCMSendMessageResultFailureDetail]?
}
