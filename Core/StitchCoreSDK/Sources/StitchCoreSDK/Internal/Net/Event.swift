import Foundation

public struct Event {
    public static let messageEvent = "message"

    public let data: String
    public let eventName: String

    init(data: String,
         eventName: String) {
        self.data = data
        if eventName.isEmpty {
            self.eventName = Event.messageEvent
        } else {
            self.eventName = eventName
        }
    }
}
