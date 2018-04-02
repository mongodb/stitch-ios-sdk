import StitchCore

/**
 * A set of methods for retrieving or modifying the authentication state of a `StitchAppClient`.
 * An implementation can be instantiated with a `StitchAppClient` instance.
 */
public protocol StitchAuth {

    // MARK: Properties

    /**
     * Whether or not the client containing this `StitchAuth` object is currently authenticated.
     */
    var isLoggedIn: Bool { get }

    /**
     * A `StitchUser` object representing the user that the client is currently authenticated as.
     * `nil` if the client is not currently authenticated.
     */
    var currentUser: StitchUser? { get }

    // MARK: Authentication Provider Clients

    /**
     * Retrieves the authentication provider client associated with the authentication provider type specified in the
     * argument.
     *
     * - parameters:
     *     - forProvider: The authentication provider conforming to `AuthProviderClientSupplier` which will provide the
     *                    client for this authentication provider. Use the `clientSupplier` field of the desired
     *                    authentication provider class.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `forProvider` parameter.
     */
    func providerClient<Provider: AuthProviderClientSupplier>(forProvider provider: Provider) -> Provider.Client

    // swiftlint:disable line_length

    /**
     * Retrieves the authentication provider client associated with the authentication provider with the specified name
     * and type.
     *
     * - parameters:
     *     - forProvider: The authentication provider conforming to `NamedAuthProviderClientSupplier` which will
     *                    provide the client for this authentication provider. Use the `NamedClientProvider` field of
     *                    the desired authentication provider class.
     *     - withName: The name of the authentication provider as defined in the MongoDB Stitch application.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `forProvider` parameter.
     */
    func providerClient<Provider: NamedAuthProviderClientSupplier>(forProvider provider: Provider, withName name: String) -> Provider.Client

    // MARK: Authentication Actions

    /**
     * Authenticates the client as a MongoDB Stitch user using the provided `StitchCredential`.
     *
     * - parameters:
     *     - withCredential: The `StitchCore.StitchCredential` used to authenticate the
     *                       client. Credentials can be retrieved from an
     *                       authentication provider client, which is retrieved
     *                       using the `providerClient` method.
     *     - completionHandler: The completion handler to call when the login is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - user: A `StitchUser` object representing the user that the client is now authenticated as, or `nil` if the
     *             login failed.
     *     - error: An error object that indicates why the login failed, or `nil` if the login was successful.
     */
    func login(withCredential credential: StitchCredential, _ completionHandler: @escaping (_ user: StitchUser?, _ error: Error?) -> Void)

    // swiftlint:enable line_length

    /**
     * Logs out the currently authenticated user, and clears any persisted
     * authentication information.
     *
     * - parameters:
     *     - completionHandler: The completion handler to call when the logout is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - error: An error object that indicates why the logout failed, or `nil` if the logout was successful.
     */
    func logout(_ completionHandler: @escaping (_ error: Error?) -> Void)

    // MARK: Delegate Registration

    /**
     * Registers a `StitchAuthDelegate` with the client. The `StitchAuthDelegate`'s `onAuthEvent(:fromAuth)`
     * method will be called with this `StitchAuth` as the argument whenever this client is authenticated
     * or is logged out.
     *
     * - important: StitchAuthDelegates registered here are stored as `weak` references, meaning that if there are no
     *              more strong references to a provided delegate, its `onAuthEvent(:fromAuth)` method will no longer
     *              be called on authentication events.
     * - parameters:
     *     - authDelegate: A class conforming to `StitchAuthDelegate`, whose `onAuthEvent(:fromAuth)` method should be
     *                     called whenever this client experiences an authentication event.
     */
    func add(authDelegate: StitchAuthDelegate)
}
