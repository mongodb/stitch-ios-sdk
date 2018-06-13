import StitchCoreSDK

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

    // swiftlint:disable line_length

    /**
     * Retrieves the authenticated authentication provider client associated with the authentication provider type
     * specified in the argument.
     *
     * - parameters:
     *     - forFactory: The authentication provider conforming to `AuthProviderClientFactory` which will provide the
     *                   client for this authentication provider. Use the `clientFactory` field of the desired
     *                   authentication provider class.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `forFactory` parameter.
     * - throws: A Stitch client error if the client is not currently authenticated.
     */
    func providerClient<Factory: AuthProviderClientFactory>(forFactory factory: Factory) throws -> Factory.ClientT where Factory.RequestClientT == StitchAuthRequestClient

    /**
     * Retrieves the authentication provider client associated with the authentication provider type specified in the
     * argument.
     *
     * - parameters:
     *     - forFactory: The authentication provider conforming to `AuthProviderClientFactory` which will provide the
     *                   client for this authentication provider. Use the `clientFactory` field of the desired
     *                   authentication provider class.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `forFactory` parameter.
     */
    func providerClient<Factory: AuthProviderClientFactory>(forFactory factory: Factory) -> Factory.ClientT where Factory.RequestClientT == StitchRequestClient

    /**
     * Retrieves the authentication provider client associated with the authentication provider with the specified name
     * and type.
     *
     * - parameters:
     *     - forFactory: The authentication provider conforming to `NamedAuthProviderClientFactory` which will
     *                   provide the client for this authentication provider. Use the `namedClientFactory` field of
     *                   the desired authentication provider class.
     *     - withName: The name of the authentication provider as defined in the MongoDB Stitch application.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `forFactory` parameter.
     */
    func providerClient<Factory: NamedAuthProviderClientFactory>(forFactory factory: Factory, withName name: String) -> Factory.Client

    // MARK: Authentication Actions

    /**
     * Authenticates the client as a MongoDB Stitch user using the provided `StitchCredential`.
     *
     * - parameters:
     *     - withCredential: The `StitchCredential` used to authenticate the
     *                       client. Credentials can be retrieved from an
     *                       authentication provider client, which is retrieved
     *                       using the `providerClient` method.
     *     - completionHandler: The completion handler to call when the login is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain a `StitchUser` object representing the user that
     *                          the client is now authenticated as.
     */
    func login(withCredential credential: StitchCredential, _ completionHandler: @escaping (StitchResult<StitchUser>) -> Void)

    // swiftlint:enable line_length

    /**
     * Logs out the currently authenticated user, and clears any persisted authentication information.
     *
     * - parameters:
     *     - completionHandler: The completion handler to call when the logout is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func logout(_ completionHandler: @escaping (StitchResult<Void>) -> Void)

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
