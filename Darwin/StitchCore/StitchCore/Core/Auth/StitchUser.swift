import Foundation
import StitchCoreSDK

/**
 * The `StitchUser` represents the the user who is logged in to the `StitchAppClient`.
 * 
 * You can retrieve an instance from `StitchAuth` or from the `StitchResult` of certain methods.
 *
 * You will find information about the user such as name and email address in the `StitchUserProfile`
 * property `profile`.
 * 
 * - SeeAlso:
 * `StitchAuth`
 */
public protocol StitchUser: CoreStitchUser {
    // MARK: Properties

    /**
     * The String representation of the ID of this Stitch user.
     */
    var id: String { get }

    /**
     * The type of [Authentication Provider](https://docs.mongodb.com/stitch/authentication/providers/)
     * used to log in as this user.
     */
    var loggedInProviderType: StitchProviderType { get }

    /**
     * The name of the [Authentication Provider](https://docs.mongodb.com/stitch/authentication/providers/)
     * used to log in as this user.
     */
    var loggedInProviderName: String { get }

    /**
     * A string describing the type of this user, either `"normal"` or `"server"`.
     *
     * `"server"` users are users authenticated via a server API key generated 
     * in the MongoDB Stitch admin console. All other users are `"normal"` users.
     */
    var userType: String { get }

    /**
     * A `StitchUserProfile` describing this user.
     */
    var profile: StitchUserProfile { get }

    /**
     * An array of `StitchUserIdentity` objects representing the identities linked
     * to this user which can be used to log in as this user.
     */
    var identities: [StitchUserIdentity] { get }

    /**
     * If this user is currently logged in.
     */
    var isLoggedIn: Bool { get }

    /**
     * The last time this user was logged in, logged out, switched to, or switched from.
     * This is stored as the `TimeInterval` (seconds) since the Unix Epoch.
     */
    var lastAuthActivity: TimeInterval { get }

    /**
     You can store arbitrary data about your application users
     in a MongoDB collection and configure Stitch to automatically
     expose each user’s data in a field of their user object.
     For example, you might store a user’s preferred language,
     date of birth, or their local timezone.

     If this functionality has not been configured, it will be empty.
     */
    var customData: Document { get }

    // MARK: Methods

    // Disabled line length rule due to https://github.com/realm/jazzy/issues/896
    // swiftlint:disable line_length
    /**
     * Links the currently authenticated `StitchUser` with a new identity, where the identity is defined by the credential
     * specified as a parameter.
     * 
     * This will only be successful if this `StitchUser` is the currently authenticated `StitchUser`.
     *
     * - parameters:
     *     - withCredential: The `StitchCore.StitchCredential` used to link the user to a new
     *                       identity. Credentials can be retrieved from an
     *                       authentication provider client, which is retrieved
     *                       using the `getProviderClient` method on `StitchAuth`.
     *     - completionHandler: The completion handler to call when the linking is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain a `StitchUser` object representing the currently
     *                          logged in user.
     */
    func link(withCredential credential: StitchCredential, _ completionHandler: @escaping (StitchResult<StitchUser>) -> Void)

    // swiftlint:enable line_length
}
