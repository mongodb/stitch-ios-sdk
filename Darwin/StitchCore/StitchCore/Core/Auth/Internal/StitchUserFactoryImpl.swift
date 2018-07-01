import Foundation
import StitchCoreSDK

/**
 * An implementation of `StitchCore.StitchUserFactory`, capable of producing `StitchUserImpl` objects.
 */
internal final class StitchUserFactoryImpl: StitchUserFactory {
    /**
     * The factory function which can produce a `StitchUserImpl` with the provided id, logged in provider type/name,
     * and a user profile.
     */
    func makeUser(withID id: String,
                  withLoggedInProviderType loggedInProviderType: StitchProviderType,
                  withLoggedInProviderName loggedInProviderName: String,
                  withUserProfile userProfile: StitchUserProfile
        ) -> StitchUserImpl {
        return StitchUserImpl.init(withID: id,
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
