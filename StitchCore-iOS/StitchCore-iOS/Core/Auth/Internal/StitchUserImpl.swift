import Foundation
import StitchCore

/**
 * An implementation of `StitchUser`.
 */
internal final class StitchUserImpl: StitchUser {

    // MARK: Private Properties

    /**
     * The `StitchAuthImpl` that was authenticated as this user.
     */
    private var auth: StitchAuthImpl

    // MARK: Initializer

    /**
     * Initializes this user with its basic properties.
     */
    init(withId id: String,
         withProviderType providerType: String,
         withProviderName providerName: String,
         withUserProfile userProfile: StitchUserProfile,
         withAuth auth: StitchAuthImpl) {
        self.auth = auth
        self.id = id
        self.loggedInProviderType = providerType
        self.loggedInProviderName = providerName
        self.profile = userProfile
    }

    // MARK: Methods

    /**
     * Links this `StitchUser` with a new identity, where the identity is defined by the credential specified as a
     * parameter. This will only be successful if this `StitchUser` is the currently authenticated `StitchUser` for the
     * client from which it was created.
     *
     * - parameters:
     *     - withCredential: The `StitchCore.StitchCredential` used to link the user to a new
     *                       identity. Credentials can be retrieved from an
     *                       authentication provider client, which is retrieved
     *                       using the `getProviderClient` method on `StitchAuth`.
     *     - completionHandler: The completion handler to call when the linking is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - user: The current user, or `nil` if the link failed.
     *     - error: An error object that indicates why the link failed, or `nil` if the link was successful.
     */
    public func link(withCredential credential: StitchCredential,
                     _ completionHandler: @escaping (StitchUser?, Error?) -> Void) {
        self.auth.link(withCredential: credential, withUser: self, completionHandler)
    }

    // MARK: Public Properties

    /**
     * The String representation of the id of this Stitch user.
     */
    public private(set) var id: String

    /**
     * A string describing the type of authentication provider used to log in as this user.
     */
    public private(set) var loggedInProviderType: String

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
