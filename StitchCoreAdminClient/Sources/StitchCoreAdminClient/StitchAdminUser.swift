import StitchCore

public final class StitchAdminUser: CoreStitchUser {

    /**
     * Initializes this user with its basic properties.
     */
    init(withId id: String,
         withProviderType providerType: StitchProviderType,
         withProviderName providerName: String,
         withUserProfile userProfile: StitchUserProfile) {
        self.id = id
        self.loggedInProviderType = providerType
        self.loggedInProviderName = providerName
        self.profile = userProfile
    }

    /**
     * The String representation of the id of this Stitch user.
     */
    public private(set) var id: String

    /**
     * A string describing the type of authentication provider used to log in as this user.
     */
    public private(set) var loggedInProviderType: StitchProviderType

    /**
     * The name of the authentication provider used to log in as this user.
     */
    public private(set) var loggedInProviderName: String

    /**
     * A string describing the type of this user. (Either `server` or `normal`)
     */
    public var userType: String {
        return self.profile.userType
    }

    /**
     * A `StitchCore.StitchUserProfile` object describing this user.
     */
    public private(set) var profile: StitchUserProfile

    /**
     * An array of `StitchCore.StitchUserIdentity` objects representing the identities linked
     * to this user which can be used to log in as this user.
     */
    public var identities: [StitchUserIdentity] {
        return self.profile.identities
    }
}

public final class StitchAdminUserFactory: StitchUserFactory {
    /**
     * The factory function which can produce a `StitchAdminUser` with the provided id, logged in provider type/name,
     * and a user profile.
     */
    public func makeUser(withId id: String,
                         withLoggedInProviderType loggedInProviderType: StitchProviderType,
                         withLoggedInProviderName loggedInProviderName: String,
                         withUserProfile userProfile: StitchUserProfile
        ) -> StitchAdminUser {
        return StitchAdminUser.init(withId: id,
                                    withProviderType: loggedInProviderType,
                                    withProviderName: loggedInProviderName,
                                    withUserProfile: userProfile)
    }

    /**
     * The user type that this `StitchUserFactory` can produce.
     */
    public typealias UserType = StitchAdminUser
}
