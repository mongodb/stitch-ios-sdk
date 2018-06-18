import Foundation
import MongoSwift

/**
 * An FCMSendMessageRequest encapsulates the details of an FCM send message request.
 */
public struct FCMSendMessageRequest: Encodable {
    /**
     * The priority of the message.
     */
    public let priority: FCMSendMessagePriority
    
    /**
     * The group of messages that can be collapsed.
     */
    public let collapseKey: String?
    
    /**
     * Whether or not to indicate to the client that content is available in order
     * to wake the device. Note: for messages to iOS devices only.
     */
    public let contentAvailable: Bool?
    
    /**
     * Whether or not the content in the message can be mutated. Note: for messages to
     * iOS devices only.
     */
    public let mutableContent: Bool?
    
    /**
     * How long (in seconds) the message should be kept in FCM storage if the device is offline.
     */
    public let timeToLive: Int64?
    
    /**
     * The custom data to send in the payload.
     */
    public let data: Document?
    
    /**
     * The predefined, user-visible key-value pairs of the notification payload.
     */
    public let notification: FCMSendMessageNotification?
}

/**
 * A builder class which can be used to prepare an FCM send message request.
 */
public class FCMSendMessageRequestBuilder {
    internal var priority: FCMSendMessagePriority?
    internal var collapseKey: String?
    internal var contentAvailable: Bool?
    internal var mutableContent: Bool?
    internal var timeToLive: Int64?
    internal var data: Document?
    internal var notification: FCMSendMessageNotification?
    
    /**
     * Sets the priority of the message.
     */
    @discardableResult
    public func with(priority: FCMSendMessagePriority) -> Self {
        self.priority = priority
        return self
    }
    
    /**
     * Sets the group of messages that can be collapsed.
     */
    @discardableResult
    public func with(collapseKey: String) -> Self {
        self.collapseKey = collapseKey
        return self
    }
    
    /**
     * Sets whether or not to indicate to the client that content is available in order
     * to wake the device. Note: for messages to iOS devices only.
     */
    @discardableResult
    public func with(contentAvailable: Bool) -> Self {
        self.contentAvailable = contentAvailable
        return self
    }
    
    /**
     * Sets whether or not the content in the message can be mutated. Note: for messages to
     * iOS devices only.
     */
    @discardableResult
    public func with(mutableContent: Bool) -> Self {
        self.mutableContent = mutableContent
        return self
    }
    
    /**
     * Sets how long (in seconds) the message should be kept in FCM storage if the device is offline.
     */
    @discardableResult
    public func with(timeToLive: Int64) -> Self {
        self.timeToLive = timeToLive
        return self
    }
    
    /**
     * Sets the custom data to send in the payload.
     */
    @discardableResult
    public func with(data: Document) -> Self {
        self.data = data
        return self
    }
    
    /**
     * Sets the predefined, user-visible key-value pairs of the notification payload.
     */
    @discardableResult
    public func with(notification: FCMSendMessageNotification) -> Self {
        self.notification = notification
        return self
    }
    
    /**
     * Initializes a new builder for an FCM send message request.
     */
    public init() { }
    
    /**
     * Builds, validates, and returns the `FCMSendMessageRequest`.
     *
     * - returns: The built FCM send message request.
     */
    public func build() -> FCMSendMessageRequest {
        return FCMSendMessageRequest.init(
            priority: priority ?? .normal,
            collapseKey: collapseKey,
            contentAvailable: contentAvailable,
            mutableContent: mutableContent,
            timeToLive: timeToLive,
            data: data,
            notification: notification
        )
    }
}

