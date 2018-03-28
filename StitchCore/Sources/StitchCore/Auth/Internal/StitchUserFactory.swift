public protocol StitchUserFactory {
    associatedtype T: CoreStitchUser

    func makeUser(withId id: String,
                  withLoggedInProviderType loggedInProviderType: String,
                  withLoggedInProviderName loggedInProviderName: String,
                  withUserProfile userProfile: StitchUserProfile) -> T
}

public class AnyStitchUserFactory<T: CoreStitchUser> {
    private let makeUserBlock: (String, String, String, StitchUserProfile) -> T

    public init<U: StitchUserFactory>(stitchUserFactory: U) where U.T == T {
        self.makeUserBlock = stitchUserFactory.makeUser
    }

    func makeUser(withId id: String,
                  withLoggedInProviderType loggedInProviderType: String,
                  withLoggedInProviderName loggedInProviderName: String,
                  withUserProfile userProfile: StitchUserProfile) -> T {
        return self.makeUserBlock(id, loggedInProviderType, loggedInProviderName, userProfile)
    }
}
