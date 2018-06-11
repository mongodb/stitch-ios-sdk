import Foundation
import StitchCore

/**
 * A struct containing the fields returned by the Stitch client API in a user profile request.
 */
public struct StitchAdminUserProfile: Decodable {
    /**
     * A string describing the type of this user.
     */
    public let userType: String

    /**
     * An array of `StitchUserIdentity` objects representing the identities linked
     * to this user which can be used to log in as this user.
     */
    public let identities: [APIStitchUserIdentity]

    /**
     * An object containing extra metadata about the user as supplied by the authentication provider.
     */
    public let data: [String: String]

    /**
     * A list of the roles that this admin user has.
     */
    public let roles: [StitchAdminRole]

    private enum CodingKeys: String, CodingKey {
        case userType = "type"
        case identities
        case data
        case roles
    }
}

public struct StitchAdminRole: Decodable {
    public var name: String
    public var groupID: String

    private enum CodingKeys: String, CodingKey {
        case name = "role_name"
        case groupID = "group_id"
    }
}
