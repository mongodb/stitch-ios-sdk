// swiftlint:disable function_parameter_count
import Foundation
import MongoSwift

/**
 * A protocol describing a factory that produces a generic Stitch user object conforming to `CoreStitchUser`.
 */
public protocol StitchUserFactory {
    /**
     * The type of user object that this `StitchUserFactory` will produce.
     */
    associatedtype UserType: CoreStitchUser

    /**
     * The factory function which will produce the user with the provided id, logged in provider type/name, and a user
     * profile.
     */
    func makeUser(withID id: String,
                  withLoggedInProviderType loggedInProviderType: StitchProviderType,
                  withLoggedInProviderName loggedInProviderName: String,
                  withUserProfile userProfile: StitchUserProfile,
                  withIsLoggedIn isLoggedIn: Bool,
                  withLastAuthActivity lastAuthActivity: TimeInterval,
                  customData: Document?) -> UserType
}

/**
 * A generic user factory class wrapping a `StitchUserFactory` that can make users of any type `T` conforming to
 * `CoreStitchUser`.
 */
public class AnyStitchUserFactory<T: CoreStitchUser> {
    /**
     * A property containing the function that produces a Stitch user object.
     */
    private let makeUserBlock: (String, StitchProviderType, String, StitchUserProfile, Bool, TimeInterval, Document?) -> T

    /**
     * Initializes this `AnyStitchUserFactory` with an arbitrary `StitchUserFactory`.
     */
    public init<U: StitchUserFactory>(stitchUserFactory: U) where U.UserType == T {
        self.makeUserBlock = stitchUserFactory.makeUser
    }

    /**
     * Initializes this `AnyStitchUserFactory` with an arbitrary closure.
     */
    public init(makeUserBlock:
        @escaping (String, StitchProviderType, String, StitchUserProfile, Bool, TimeInterval, Document?) -> T) {
        self.makeUserBlock = makeUserBlock
    }

    /**
     * Produces a new Stitch user with the stored `makeUserBlock`.
     */
    public func makeUser(withID id: String,
                         withLoggedInProviderType loggedInProviderType: StitchProviderType,
                         withLoggedInProviderName loggedInProviderName: String,
                         withUserProfile userProfile: StitchUserProfile,
                         withIsLoggedIn isLoggedIn: Bool,
                         withLastAuthActivity lastAuthActivity: TimeInterval,
                         customData: Document?) -> T {
        return self.makeUserBlock(id,
                                  loggedInProviderType,
                                  loggedInProviderName,
                                  userProfile,
                                  isLoggedIn,
                                  lastAuthActivity,
                                  customData)
    }
}
// swiftlint:enable function_parameter_count
