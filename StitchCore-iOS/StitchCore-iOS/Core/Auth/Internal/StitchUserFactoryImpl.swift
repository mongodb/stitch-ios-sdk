import Foundation
import StitchCore

internal final class StitchUserFactoryImpl: StitchUserFactory {
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

    public typealias UserType = StitchUserImpl

    private let auth: StitchAuthImpl

    init(withAuth auth: StitchAuthImpl) {
        self.auth = auth
    }
}
