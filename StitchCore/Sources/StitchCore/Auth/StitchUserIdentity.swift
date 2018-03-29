/**
 * A class representing an identity that a Stitch user is linked to and can use to sign into their account.
 */
public protocol StitchUserIdentity: Decodable {
    /**
     * The ID of this identity in MongoDB Stitch
     *
     * - important: This is **not** the ID of the Stitch user.
     */
    var id: String { get }

    /**
     * A string indicating the authentication provider that provides this identity.
     */
    var providerType: String { get }
}

/**
 * An overload of `==` that checks if two `StitchUserIdentity` objects are equal based on their ID and provider type.
 */
public func == (_ lhs: StitchUserIdentity, _ rhs: StitchUserIdentity) -> Bool {
    return lhs.id == rhs.id && lhs.providerType == rhs.providerType
}
