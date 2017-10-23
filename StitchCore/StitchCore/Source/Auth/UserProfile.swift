import Foundation

// MARK: - Identity
/**
 Identity is an alias by which this user can be authenticated in as.
 */
public struct Identity: Codable {
    private enum CodingKeys: CodingKey {
        case id, provider
    }
    /**
     The provider specific Unique ID.
     */
    private let id: String
    /**
     The provider of this identity.
     */
    private let provider: String
}

/**
    UserProfile represents an authenticated user.
 */
public struct UserProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case id = "userId"
        case identities, data
    }

    /**
        The Unique ID of this user within Stitch.
     */
    public let id: String
    /**
        The set of identities that this user is known by.
     */
    public let identities: [Identity]
    /**
        The extra data associated with this user.
     */
    public let data: [String: String]
}
