import Foundation

/**
 * An FCMSendMessageNotification encapsulates the details of an FCM send message request notification payload.
 */
public struct FCMSendMessageNotification: Encodable {
    /**
     * The notification's title.
     */
    public let title: String?

    /**
     * The notification's body text.
     */
    public let body: String?

    /**
     * The sound to play when the device receives the notification.
     */
    public let sound: String?

    /**
     * The action associated with a user click on the notification.
     */
    public let clickAction: String?

    /**
     * The the key to the body string in the app's string resources to use to localize the body
     * text to the user's current localization.
     */
    public let bodyLocKey: String?

    /**
     * The variable string values to be used in place of the format specifiers in
     * bodyLocKey to use to localize the body text to the user's current localization.
     */
    public let bodyLocArgs: String?

    /**
     * The key to the title string in the app's string resources to use to localize the
     * title text to the user's current localization.
     */
    public let titleLocKey: String?

    /**
     * The variable string values to be used in place of the format specifiers in
     * titleLocKey to use to localize the title text to the user's current localization.
     */
    public let titleLocArgs: String?

    /**
     * The notification's icon. Note: for messages to Android devices only.
     */
    public let icon: String?

    /**
     * The identifier used to replace existing notifications in the notification drawer.
     * Note: for messages to Android devices only.
     */
    public let tag: String?

    /**
     * The notification's icon color, expressed in #rrggbb format. Note: for messages to
     * Android devices only.
     */
    public let color: String?

    /**
     * The value of the badge on the home screen app icon. Note: for messages to iOS devices only.
     */
    public let badge: String?
}

/**
 * A builder class which can be used to prepare the notification inside of an FCM send message request.
 */
public class FCMSendMessageNotificationBuilder {
    internal var title: String?
    internal var body: String?
    internal var sound: String?
    internal var clickAction: String?
    internal var bodyLocKey: String?
    internal var bodyLocArgs: String?
    internal var titleLocKey: String?
    internal var titleLocArgs: String?
    internal var icon: String?
    internal var tag: String?
    internal var color: String?
    internal var badge: String?

    /**
     * Initializes a new builder for an FCM send message notification.
     */
    public init() { }

    /**
     * Sets the notification's title.
     */
    @discardableResult
    public func with(title: String) -> Self {
        self.title = title
        return self
    }

    /**
     * Sets the notification's body text.
     */
    @discardableResult
    public func with(body: String) -> Self {
        self.body = body
        return self
    }

    /**
     * Sets the sound to play when the device receives the notification.
     */
    @discardableResult
    public func with(sound: String) -> Self {
        self.sound = sound
        return self
    }

    /**
     * Sets the action associated with a user click on the notification.
     */
    @discardableResult
    public func with(clickAction: String) -> Self {
        self.clickAction = clickAction
        return self
    }

    /**
     * Sets the key to the body string in the app's string resources to use to localize the body
     * text to the user's current localization.
     */
    @discardableResult
    public func with(bodyLocKey: String) -> Self {
        self.bodyLocKey = bodyLocKey
        return self
    }

    /**
     * Sets the variable string values to be used in place of the format specifiers in
     * bodyLocKey to use to localize the body text to the user's current localization.
     */
    @discardableResult
    public func with(bodyLocArgs: String) -> Self {
        self.bodyLocArgs = bodyLocArgs
        return self
    }

    /**
     * Sets the key to the title string in the app's string resources to use to localize the
     * title text to the user's current localization.
     */
    @discardableResult
    public func with(titleLocKey: String) -> Self {
        self.titleLocKey = titleLocKey
        return self
    }

    /**
     * Sets the variable string values to be used in place of the format specifiers in
     * titleLocKey to use to localize the title text to the user's current localization.
     */
    @discardableResult
    public func with(titleLocArgs: String) -> Self {
        self.titleLocArgs = titleLocArgs
        return self
    }

    /**
     * Sets the notification's icon. Note: for messages to Android devices only.
     */
    @discardableResult
    public func with(icon: String) -> Self {
        self.icon = icon
        return self
    }

    /**
     * Sets the identifier used to replace existing notifications in the notification drawer.
     * Note: for messages to Android devices only.
     */
    @discardableResult
    public func with(tag: String) -> Self {
        self.tag = tag
        return self
    }

    /**
     * Sets the notification's icon color, expressed in #rrggbb format. Note: for messages to
     * Android devices only.
     */
    @discardableResult
    public func with(color: String) -> Self {
        self.color = color
        return self
    }

    /**
     * Sets the value of the badge on the home screen app icon. Note: for messages to iOS devices only.
     */
    @discardableResult
    public func with(badge: String) -> Self {
        self.badge = badge
        return self
    }

    /**
     * Builds, validates, and returns the `FCMSendMessageNotification`.
     *
     * - returns: The built notification.
     */
    public func build() -> FCMSendMessageNotification {
        return FCMSendMessageNotification.init(
            title: title,
            body: body,
            sound: sound,
            clickAction: clickAction,
            bodyLocKey: bodyLocKey,
            bodyLocArgs: bodyLocArgs,
            titleLocKey: titleLocKey,
            titleLocArgs: titleLocArgs,
            icon: icon,
            tag: tag,
            color: color,
            badge: badge
        )
    }
}
