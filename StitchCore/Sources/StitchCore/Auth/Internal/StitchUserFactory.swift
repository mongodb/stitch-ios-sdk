public protocol StitchUserFactory {
    associatedtype UserType: CoreStitchUser

    func makeUser(withId id: String,
                  withLoggedInProviderType loggedInProviderType: String,
                  withLoggedInProviderName loggedInProviderName: String,
                  withUserProfile userProfile: StitchUserProfile) -> UserType
}

public class AnyStitchUserFactory<T: CoreStitchUser> {
    private let makeUserBlock: (String, String, String, StitchUserProfile) -> T

    public init<U: StitchUserFactory>(stitchUserFactory: U) where U.UserType == T {
        self.makeUserBlock = stitchUserFactory.makeUser
    }

    func makeUser(withId id: String,
                  withLoggedInProviderType loggedInProviderType: String,
                  withLoggedInProviderName loggedInProviderName: String,
                  withUserProfile userProfile: StitchUserProfile) -> T {
        return self.makeUserBlock(id, loggedInProviderType, loggedInProviderName, userProfile)
    }
}
