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
}

/**
 * An `==` overload checking if the two provided `CoreStitchUser`s have the same id.
 */
public func ==(_ lhs: CoreStitchUser,
               _ rhs: CoreStitchUser) -> Bool {
    return lhs.id == rhs.id
}
