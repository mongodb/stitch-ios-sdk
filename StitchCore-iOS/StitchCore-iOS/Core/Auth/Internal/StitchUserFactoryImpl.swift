import Foundation
import StitchCore

/**
 * An implementation of `StitchCore.StitchUserFactory`, capable of producing `StitchUserImpl` objects.
 */
internal final class StitchUserFactoryImpl: StitchUserFactory {
    /**
     * The factory function which can produce a `StitchUserImpl` with the provided ID, logged in provider type/name,
     * and a user profile.
     */
    func makeUser(withId id: String,
                  withLoggedInProviderType loggedInProviderType: String,
                  withLoggedInProviderName loggedInProviderName: String,
                  withUserProfile userProfile: StitchUserProfile
        ) -> StitchUserImpl {
        return StitchUserImpl.init(withId: id,
                                   withProviderType: loggedInProviderType,
                                   withProviderName: loggedInProviderName,
                                   withUserProfile: userProfile,
                                   withAuth: self.auth)
    }

    /**
     * The user type that this `StitchUserFactory` can produce.
     */
    public typealias UserType = StitchUserImpl

    /**
     * The underlying `StitchAuthImpl` from which this user was created.
     */
    private let auth: StitchAuthImpl

    /**
     * Initializes this factory with a `StitchAuthImpl`.
     */
    init(withAuth auth: StitchAuthImpl) {
        self.auth = auth
    }
}
