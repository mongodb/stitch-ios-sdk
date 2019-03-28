import Foundation
import MongoSwift
@testable import StitchCoreSDK

struct MockStitchUser: CoreStitchUser {
    var id: String = ""

    var loggedInProviderType: StitchProviderType = .anonymous

    var loggedInProviderName: String = ""

    var userType: String = ""

    var profile: StitchUserProfile =
        StitchUserProfileImpl.init(
            userType: "anon-user",
            identities: [APIStitchUserIdentity.init(id: ObjectId().description,
                                                    providerType: "anon-user")],
            data: APIExtendedUserProfileImpl.init()
    )

    var identities: [StitchUserIdentity] = []

    var isLoggedIn: Bool = false

    var lastAuthActivity: TimeInterval = Date.init().timeIntervalSince1970

    static func == (lhs: MockStitchUser,
                    rhs: MockStitchUser) -> Bool {
        return lhs.id == rhs.id
    }

    init() {}
    init(id: String,
         loggedInProviderType: StitchProviderType,
         loggedInProviderName: String,
         profile: StitchUserProfile) {
        self.id = id
        self.loggedInProviderType = loggedInProviderType
        self.loggedInProviderName = loggedInProviderName
        self.profile = profile
    }
}
