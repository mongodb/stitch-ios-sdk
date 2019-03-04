import Foundation

/**
 Enumeration of possible events that can signal
 a service rebind.
*/
public enum RebindEventType {
    /// Any rebind event related to auth.
    case authEvent
}

public protocol RebindEvent {
    var type: RebindEventType { get }
}

/**
  A protocol that allows any service of any type
  to bind to it's associated [CoreStitchServiceClient](x-source-tag://CoreStitchServiceClient).
 */
public protocol StitchServiceBinder: class {
    /**
      Notify the binder that a rebind event has occured.
      E.g., a change in authentication.

      - parameter rebindEvent the rebind event that occurred
     */
    func onRebindEvent(_ rebindEvent: RebindEvent)
}

class AnyStitchServiceBinder: StitchServiceBinder {
    weak var reference: StitchServiceBinder?
    init(_ reference: StitchServiceBinder) {
        self.reference = reference
    }

    func onRebindEvent(_ rebindEvent: RebindEvent) {
        self.reference?.onRebindEvent(rebindEvent)
    }
}
