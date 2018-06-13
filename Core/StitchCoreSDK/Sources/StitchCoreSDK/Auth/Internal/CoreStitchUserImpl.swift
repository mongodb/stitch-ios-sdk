import Foundation

open class CoreStitchUserImpl: CoreStitchUser {
    public let id: String
    
    public let loggedInProviderType: StitchProviderType
    
    public let loggedInProviderName: String
    
    public let profile: StitchUserProfile
    
    public var userType: String {
        return self.profile.userType
    }
    
    public var identities: [StitchUserIdentity] {
        return self.profile.identities
    }
    
    public init(id: String,
         loggedInProviderType: StitchProviderType,
         loggedInProviderName: String,
         profile: StitchUserProfile
        ) {
        self.id = id
        self.loggedInProviderType = loggedInProviderType
        self.loggedInProviderName = loggedInProviderName
        self.profile = profile
    }
}
