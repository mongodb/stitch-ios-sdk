/**
 * A protocol representing an identity that a Stitch user is linked to and can use to sign into their account.
 */
public protocol StitchUserIdentity: Codable {
    /**
     * The id of this identity in MongoDB Stitch
     *
     * - important: This is **not** the id of the Stitch user.
     */
    var id: String { get }

    /**
     * A string indicating the authentication provider that provides this identity.
     */
    var providerType: String { get }
}

/**
 * :nodoc:
 * An overload of `==` that checks if two `StitchUserIdentity` objects are equal based on their id and provider type.
 */
public func ==(_ lhs: StitchUserIdentity, _ rhs: StitchUserIdentity) -> Bool {
    return lhs.id == rhs.id && lhs.providerType == rhs.providerType
}
