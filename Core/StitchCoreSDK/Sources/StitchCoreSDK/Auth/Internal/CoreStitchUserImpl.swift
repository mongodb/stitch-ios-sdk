import Foundation
import MongoSwift

open class CoreStitchUserImpl: CoreStitchUser {
    public let id: String

    public let loggedInProviderType: StitchProviderType

    public let loggedInProviderName: String

    public let lastAuthActivity: TimeInterval

    public let profile: StitchUserProfile

    public var userType: String {
        return self.profile.userType
    }

    public var identities: [StitchUserIdentity] {
        return self.profile.identities
    }

    public let isLoggedIn: Bool

    internal var backingCustomData: Document?
    public var customData: Document {
        return backingCustomData ?? [:]
    }

    public init(id: String,
                loggedInProviderType: StitchProviderType,
                loggedInProviderName: String,
                profile: StitchUserProfile,
                isLoggedIn: Bool,
                lastAuthActivity: TimeInterval,
                customData: Document?
    ) {
        self.id = id
        self.loggedInProviderType = loggedInProviderType
        self.loggedInProviderName = loggedInProviderName
        self.profile = profile
        self.isLoggedIn = isLoggedIn
        self.lastAuthActivity = lastAuthActivity
        self.backingCustomData = customData
    }
}
