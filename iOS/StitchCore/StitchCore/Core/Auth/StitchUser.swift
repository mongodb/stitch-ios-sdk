import StitchCoreSDK

/**
 * A set of methods and properties that represent a user that a `StitchAppClient` is currently authenticated as.
 * Can be instantiated from a `StitchAuth` or as a parameter to an authentication completion handler.
 */
public protocol StitchUser: CoreStitchUser {
    // MARK: Properties

    /**
     * The String representation of the id of this Stitch user.
     */
    var id: String { get }

    /**
     * The type of authentication provider used to log in as this user.
     */
    var loggedInProviderType: StitchProviderType { get }

    /**
     * The name of the authentication provider used to log in as this user.
     */
    var loggedInProviderName: String { get }

    /**
     * A string describing the type of this user. (Either `server` or `normal`)
     */
    var userType: String { get }

    /**
     * A `StitchCore.StitchUserProfile` object describing this user.
     */
    var profile: StitchUserProfile { get }

    /**
     * An array of `StitchCore.StitchUserIdentity` objects representing the identities linked
     * to this user which can be used to log in as this user.
     */
    var identities: [StitchUserIdentity] { get }

    // MARK: Methods

    // swiftlint:disable line_length

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
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain a `StitchUser` object representing the currently
     *                          logged in user.
     */
    func link(withCredential credential: StitchCredential, _ completionHandler: @escaping (StitchResult<StitchUser>) -> Void)

    // swiftlint:enable line_length
}
