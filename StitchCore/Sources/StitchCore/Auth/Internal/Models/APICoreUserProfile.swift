import Foundation
import MongoSwift

/**
 * A struct containing the fields returned by the Stitch client API in the `data` field of a user profile request.
 */
public struct APIExtendedUserProfileImpl: Codable, ExtendedStitchUserProfile {
    enum CodingKeys: String, CodingKey {
        case name, email, pictureURL = "picture_url"
        case firstName = "first_name", lastName = "last_name"
        case gender, birthday
        case minAge = "min_age", maxAge = "max_age"
    }

    /**
     * The full name of the user.
     */
    public let name: String?

    /**
     * The email address of the user.
     */
    public let email: String?

    /**
     * A URL to the user's profile picture.
     */
    public let pictureURL: String?

    /**
     * The first name of the user.
     */
    public let firstName: String?

    /**
     * The last name of the user.
     */
    public let lastName: String?

    /**
     * The gender of the user.
     */
    public let gender: String?

    /**
     * The birthdate of the user.
     */
    public let birthday: String?

    /**
     * The minimum age of the user.
     */
    public let minAge: Int?

    /**
     * The maximum age of the user.
     */
    public let maxAge: Int?

    /**
     * Initializes the user profile object with each of its properties as optional parameters.
     */
    internal init(name: String? = nil,
                  email: String? = nil,
                  pictureURL: String? = nil,
                  firstName: String? = nil,
                  lastName: String? = nil,
                  gender: String? = nil,
                  birthday: String? = nil,
                  minAge: Int? = nil,
                  maxAge: Int? = nil) {
        self.name = name
        self.email = email
        self.pictureURL = pictureURL
        self.firstName = firstName
        self.lastName = lastName
        self.gender = gender
        self.birthday = birthday
        self.minAge = minAge
        self.maxAge = maxAge
    }
}

/**
 * A struct containing the fields returned by the Stitch client API in a user profile request.
 */
public struct APICoreUserProfileImpl: Codable, APIStitchUserProfile {
    /**
     * A string describing the type of this user. (Either `server` or `normal`)
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
    public let data: APIExtendedUserProfileImpl

    private enum CodingKeys: String, CodingKey {
        case userType = "type"
        case identities
        case data
    }

    /**
     * Initializes the API user profile with its properties as arguments.
     */
    internal init(userType: String,
                  identities: [APIStitchUserIdentity],
                  data: APIExtendedUserProfileImpl) {
        self.userType = userType
        self.identities = identities
        self.data = data
    }
}
