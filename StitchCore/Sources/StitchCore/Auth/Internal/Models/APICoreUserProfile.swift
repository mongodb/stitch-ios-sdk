import Foundation
import ExtendedJSON

public struct APIExtendedUserProfileImpl: Codable, ExtendedStitchUserProfile {
    enum CodingKeys: String, CodingKey {
        case name, email, pictureURL = "picture_url"
        case firstName = "first_name", lastName = "last_name"
        case gender, birthday
        case minAge = "min_age", maxAge = "max_age"
    }

    public let name: String?

    public let email: String?

    public let pictureURL: String?

    public let firstName: String?

    public let lastName: String?

    public let gender: String?

    public let birthday: String?

    public let minAge: Int?

    public let maxAge: Int?

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

public struct APICoreUserProfileImpl: Decodable, APIStitchUserProfile {
    public let userType: String
    public let identities: [StitchUserIdentity]
    public let data: APIExtendedUserProfileImpl

    private enum CodingKeys: String, CodingKey {
        case userType = "type"
        case identities
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.userType = try container.decode(String.self, forKey: .userType)
        self.identities = try container.decode([APIStitchUserIdentity].self, forKey: .identities)
        self.data = try container.decode(APIExtendedUserProfileImpl.self, forKey: .data)
    }

    internal init(userType: String,
                  identities: [StitchUserIdentity],
                  data: APIExtendedUserProfileImpl) {
        self.userType = userType
        self.identities = identities
        self.data = data
    }
}
