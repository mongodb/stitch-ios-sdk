import Foundation
import ExtendedJSON

internal final class StoreCoreUserProfile: Codable, StitchUserProfile {
    enum CodingKeys: CodingKey {
        case userType, data, identities
    }

    lazy var name: String? = data.name
    lazy var email: String? = data.email
    lazy var pictureURL: String? = data.pictureURL
    lazy var firstName: String? = data.firstName
    lazy var lastName: String? = data.lastName
    lazy var gender: String? = data.gender
    lazy var birthday: String? = data.birthday
    lazy var minAge: Int? = data.minAge
    lazy var maxAge: Int? = data.maxAge

    let userType: String
    let data: APIExtendedUserProfileImpl
    let identities: [StitchUserIdentity]

    init(withUserProfile userProfile: StitchUserProfile) {
        self.userType = userProfile.userType
        self.data = userProfile.data
        self.identities = userProfile.identities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.userType = try container.decode(String.self, forKey: .userType)
        self.data = try container.decode(APIExtendedUserProfileImpl.self, forKey: .data)
        self.identities = try container.decode([StoreStitchUserIdentity].self, forKey: .identities)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.userType, forKey: .userType)
        try container.encode(self.data, forKey: .data)
        try container.encode(self.identities.map { StoreStitchUserIdentity.init(withIdentity: $0) },
                             forKey: .identities)
    }
}
