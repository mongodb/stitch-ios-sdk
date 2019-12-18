import Foundation
import MongoSwift

/**
 * The set of properties that describe an authenticated Stitch user.
 */
public protocol CoreStitchUser {
    /**
     * The id of the Stitch user.
     */
    var id: String { get }

    /**
     * The type of authentication provider used to log in as this user.
     */
    var loggedInProviderType: StitchProviderType { get }

    /**
     * The name of the authentication provider used to log in as this user.
     */
    var loggedInProviderName: String { get }

    /**
     * A Bool indicating whether this user is logged in (meaning whether or not there is auth info
     * available for this user). If a user is logged in, it means that they can be switched to
     * without re-authenticating with the server.
     */
    var isLoggedIn: Bool { get }

    /**
     * A string describing the type of this user. (Either `server` or `normal`)
     */
    var userType: String { get }

    /**
     * A `StitchUserProfile` object describing this user.
     */
    var profile: StitchUserProfile { get }

    /**
     * An array of `StitchUserIdentity` objects representing the identities linked
     * to this user which can be used to log in as this user.
     */
    var identities: [StitchUserIdentity] { get }

    /**
     * The last time that this user was logged into, switched to, or switched from
     */
    var lastAuthActivity: TimeInterval { get }

    /**
     You can store arbitrary data about your application users
     in a MongoDB collection and configure Stitch to automatically
     expose each user’s data in a field of their user object.
     For example, you might store a user’s preferred language,
     date of birth, or their local timezone.

     If this value has not been configured, it will be empty.
     */
    var customData: Document { get }
}

/**
 * An `==` overload checking if the two provided `CoreStitchUser`s have the same id.
 */
public func == (_ lhs: CoreStitchUser,
                _ rhs: CoreStitchUser) -> Bool {
    return lhs.id == rhs.id
}
