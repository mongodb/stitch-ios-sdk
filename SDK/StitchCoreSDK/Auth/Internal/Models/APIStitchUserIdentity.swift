/**
 * A struct representing the structure of a Stitch identity as it may be described in the `identities` field
 * of the response to a user profile request.
 */
public struct APIStitchUserIdentity: StitchUserIdentity, Hashable {
    /**
     * The hash value of the id to provide conformance to `Hashable`.
     */
    public var hashValue: Int {
        return self.id.hashValue
    }

    /**
     * An overload of `==` to compare two `APIStitchUserIdentity` objects by id.
     */
    public static func ==(lhs: APIStitchUserIdentity, rhs: APIStitchUserIdentity) -> Bool {
        return lhs.id == rhs.id
    }

    /**
     * The id of this identity in MongoDB Stitch
     *
     * - important: This is **not** the id of the Stitch user.
     */
    public var id: String

    /**
     * A string indicating the authentication provider that provides this identity.
     */
    public var providerType: String

    private enum CodingKeys: String, CodingKey {
        case id = "id"
        case providerType = "provider_type"
    }
}
