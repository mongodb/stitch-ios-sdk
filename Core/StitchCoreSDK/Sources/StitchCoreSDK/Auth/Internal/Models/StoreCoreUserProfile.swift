import Foundation
import MongoSwift

/**
 * A struct describing the structure of how user profile information is stored in persisted `Storage`.
 */
internal final class StoreCoreUserProfile: Codable, StitchUserProfile {
    enum CodingKeys: CodingKey {
        case userType, data, identities
    }

    /**
     * The full name of the user.
     */
    lazy var name: String? = self.data.name

    /**
     * The email address of the user.
     */
    lazy var email: String? = self.data.email

    /**
     * A URL to the user's profile picture.
     */
    lazy var pictureURL: String? = self.data.pictureURL

    /**
     * The first name of the user.
     */
    lazy var firstName: String? = self.data.firstName

    /**
     * The last name of the user.
     */
    lazy var lastName: String? = self.data.lastName

    /**
     * The gender of the user.
     */
    lazy var gender: String? = self.data.gender

    /**
     * The birthdate of the user.
     */
    lazy var birthday: String? = self.data.birthday

    /**
     * The minimum age of the user.
     */
    lazy var minAge: Int? = self.data.minAge

    /**
     * The maximum age of the user.
     */
    lazy var maxAge: Int? = self.data.maxAge

    /**
     * A string describing the type of this user. (Either `server` or `normal`)
     */
    let userType: String

    /**
     * An object containing extra metadata about the user as supplied by the authentication provider.
     */
    let data: APIExtendedUserProfileImpl

    /**
     * An array of `StitchUserIdentity` objects representing the identities linked
     * to this user which can be used to log in as this user.
     */
    let identities: [StitchUserIdentity]

    /**
     * Initializes the `StoreCoreUserProfile` with a plain `StitchUserProfile`.
     */
    init(withUserProfile userProfile: StitchUserProfile) {
        self.userType = userProfile.userType
        self.data = userProfile.data
        self.identities = userProfile.identities
    }

    /**
     * Initializes the `StoreCoreUserProfile` from a decoder.
     */
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.userType = try container.decode(String.self, forKey: .userType)
        self.data = try container.decode(APIExtendedUserProfileImpl.self, forKey: .data)
        self.identities = try container.decode([StoreStitchUserIdentity].self, forKey: .identities)
    }

    /**
     * Encodes the `StoreCoreUserProfile` to an encoder.
     */
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.userType, forKey: .userType)
        try container.encode(self.data, forKey: .data)
        try container.encode(self.identities.map { StoreStitchUserIdentity.init(withIdentity: $0) },
                             forKey: .identities)
    }
}
