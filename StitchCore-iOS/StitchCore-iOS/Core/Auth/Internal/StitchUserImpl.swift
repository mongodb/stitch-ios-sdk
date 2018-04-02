import Foundation
import StitchCore

internal final class StitchUserImpl: StitchUser {
    private var auth: StitchAuthImpl

    init(withId id: String,
         withProviderType providerType: String,
         withProviderName providerName: String,
         withUserProfile userProfile: StitchUserProfile,
         withAuth auth: StitchAuthImpl) {
        self.auth = auth
        self.id = id
        self.loggedInProviderType = providerType
        self.loggedInProviderName = providerName
        self.profile = userProfile
    }

    public func link(withCredential credential: StitchCredential,
                     _ completionHandler: @escaping (StitchUser?, Error?) -> Void) {
        self.auth.link(withCredential: credential, withUser: self, completionHandler)
    }

    public private(set) var id: String

    public private(set) var loggedInProviderType: String

    public private(set) var loggedInProviderName: String

    public var userType: String {
        return self.profile.userType
    }

    public private(set) var profile: StitchUserProfile

    public var identities: [StitchUserIdentity] {
        return self.profile.identities
    }
}
