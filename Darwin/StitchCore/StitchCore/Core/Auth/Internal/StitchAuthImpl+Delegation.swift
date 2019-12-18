import Foundation
import StitchCoreSDK

/**
 * Extension functions for `StitchAuthImpl` for `StitchAuthDelegate`-related functions
 */
extension StitchAuthImpl {
    /**
     * Registers a `StitchAuthDelegate` with the client. The `StitchAuthDelegate`'s `onAuthEvent(:fromAuth)`
     * method will be called with this `StitchAuth` as the argument whenever this client is authenticated
     * or is logged out.
     *
     * - important: StitchAuthDelegates registered here are stored as `weak` references, meaning that if there are no
     *              more strong references to a provided delegate, its `onAuthEvent(:fromAuth)` method will no longer
     *              be called on authentication events.
     * - parameters:
     *     - authDelegate: A class conforming to `StitchAuthDelegate`, whose `onAuthEvent(:fromAuth)` method should be
     *                     called whenever this client experiences an authentication event.
     */
    public func add(authDelegate: StitchAuthDelegate) {
        objc_sync_enter(self)
        self.delegates.append(AnyStitchAuthDelegate(authDelegate))
        objc_sync_exit(self)

        // Dispatch the delegate registered event
        dispatcher.queue.async {
            self.dispatch(authEvent: AuthRebindEvent.delegateRegistered, toDelegate: authDelegate)
        }
    }

    /**
     * Adds a synchronous delegate which is used internally to perform rebind events that need to happen synchronously
     * when auth events happen.
     */
    internal func add(synchronousAuthDelegate: StitchAuthDelegate) {
        objc_sync_enter(self)
        self.synchronousDelegates.append(AnyStitchAuthDelegate(synchronousAuthDelegate))
        objc_sync_exit(self)

        // Dispatch the delegate registered event
        self.dispatch(authEvent: AuthRebindEvent.delegateRegistered, toDelegate: synchronousAuthDelegate)
    }

    /**
     * Given an internal `AuthRebindEvent`, calls the appropriate method on the provided `StitchAuthDelegate`
     */
    internal func dispatch(authEvent: AuthRebindEvent, toDelegate delegate: StitchAuthDelegate) {
        switch authEvent {
        case .delegateRegistered:
            delegate.onDelegateRegistered(auth: self)
        case .userLoggedIn(let loggedInUser):
            delegate.onUserLoggedIn(auth: self, loggedInUser: self.makeUser(loggedInUser))
        case .userLoggedOut(let loggedOutUser):
            delegate.onUserLoggedOut(auth: self, loggedOutUser: self.makeUser(loggedOutUser))
        case .userLinked(let linkedUser):
            delegate.onUserLinked(auth: self, linkedUser: self.makeUser(linkedUser))
        case .activeUserChanged(let currentActiveUser, let previousActiveUser):
            var currentActiveStitchUser: StitchUser?
            var previousActiveStitchUser: StitchUser?

            if let currentActiveUser = currentActiveUser {
                currentActiveStitchUser = self.makeUser(currentActiveUser)
            }
            if let previousActiveUser = previousActiveUser {
                previousActiveStitchUser = self.makeUser(previousActiveUser)
            }
            delegate.onActiveUserChanged(
                auth: self,
                currentActiveUser: currentActiveStitchUser,
                previousActiveUser: previousActiveStitchUser)
        case .userRemoved(let removedUser):
            delegate.onUserRemoved(auth: self, removedUser: self.makeUser(removedUser))
        case .userAdded(let addedUser):
            delegate.onUserAdded(auth: self, addedUser: self.makeUser(addedUser))
        }

        delegate.onAuthEvent(fromAuth: self)
    }

    /**
     * Utility for creating `StitchUser` objects from a `CoreStitchUser` object.
     */
    private func makeUser(_ user: CoreStitchUser) -> StitchUser {
        return userFactory.makeUser(withID: user.id,
                                    withLoggedInProviderType: user.loggedInProviderType,
                                    withLoggedInProviderName: user.loggedInProviderName,
                                    withUserProfile: user.profile,
                                    withIsLoggedIn: user.isLoggedIn,
                                    withLastAuthActivity: user.lastAuthActivity,
                                    customData: user.customData)
    }
}
