import Foundation

public enum AuthRebindEvent: RebindEvent {
    public var type: RebindEventType {
        return .authEvent
    }

    case delegateRegistered
    case userLoggedIn(loggedInUser: CoreStitchUser)
    case userLoggedOut(loggedOutUser: CoreStitchUser)
    case userLinked(linkedUser: CoreStitchUser)
    case activeUserChanged(currentActiveUser: CoreStitchUser?, previousActiveUser: CoreStitchUser?)
    case userRemoved(removedUser: CoreStitchUser)
    case userAdded(addedUser: CoreStitchUser)
}
