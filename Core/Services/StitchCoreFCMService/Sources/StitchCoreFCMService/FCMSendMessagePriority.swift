import Foundation

/**
 * FCMSendMessagePriority indicates the priority of a message.
 */
public enum FCMSendMessagePriority: String, Encodable {
    case normal
    case high
}
