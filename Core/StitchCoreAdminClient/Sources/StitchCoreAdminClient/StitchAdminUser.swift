import StitchCoreSDK
import Foundation

public final class StitchAdminUser: CoreStitchUser {

    /**
     * Initializes this user with its basic properties.
     */
    init(withID id: String,
         withProviderType providerType: StitchProviderType,
         withProviderName providerName: String,
         withUserProfile userProfile: StitchUserProfile,
         withIsLoggedIn isLoggedIn: Bool,
         withLastAuthActivity lastAuthActivity: TimeInterval) {
        self.id = id
        self.loggedInProviderType = providerType
        self.loggedInProviderName = providerName
        self.profile = userProfile
        self.isLoggedIn = isLoggedIn
        self.lastAuthActivity = lastAuthActivity
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
     * A Bool describing if the user is logged in
     */
    public private(set) var isLoggedIn: Bool

    /**
     * A TimeInterval determining the last time that the user logged in, was logged out
     * switched to, or switched from
     */
    public private(set) var lastAuthActivity: TimeInterval

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
    //swiftlint:disable function_parameter_count
    public func makeUser(withID id: String,
                         withLoggedInProviderType loggedInProviderType: StitchProviderType,
                         withLoggedInProviderName loggedInProviderName: String,
                         withUserProfile userProfile: StitchUserProfile,
                         withIsLoggedIn isLoggedIn: Bool,
                         withLastAuthActivity lastAuthActivity: TimeInterval
        ) -> StitchAdminUser {
        return StitchAdminUser.init(withID: id,
                                    withProviderType: loggedInProviderType,
                                    withProviderName: loggedInProviderName,
                                    withUserProfile: userProfile,
                                    withIsLoggedIn: isLoggedIn,
                                    withLastAuthActivity: lastAuthActivity)
    }
    //swiftlint:enable function_parameter_count

    /**
     * The user type that this `StitchUserFactory` can produce.
     */
    public typealias UserType = StitchAdminUser
}
