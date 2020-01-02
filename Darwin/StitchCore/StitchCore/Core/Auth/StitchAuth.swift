import StitchCoreSDK

/**
 * The `StitchAuth` provides methods for retrieving or modifying the authentication
 * state of a `StitchAppClient`.
 *
 * Each `StitchAppClient` has an instance of StitchAuth.
 *
 * Information about the logged-in `StitchUser` is available in the `currentUser` property.
 *
 * To watch for auth events, add a `StitchAuthDelegate`.
 *
 * - SeeAlso:
 * `StitchAppClient`,
 * `StitchUser`,
 * `StitchAuthDelegate`
 * 
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

    // Disabled line length rule due to https://github.com/realm/jazzy/issues/896
    // swiftlint:disable line_length

    /**
     * Retrieves the authenticated authentication provider client for the authentication provider associated with the
     * specified factory.
     *
     * - parameters:
     *     - fromFactory: The `AuthProviderClientFactory` which will provide the client for this authentication
     *                    provider. Each authentication provider that has extra functionality beyond logging in/linking
     *                    will offer a static factory which can be used for this method.
     *
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `fromFactory` parameter.
     */
    func providerClient<Factory: AuthProviderClientFactory>(fromFactory factory: Factory) -> Factory.ClientT where Factory.RequestClientT == StitchAuthRequestClient

    /**
     * Retrieves the authentication provider client for the authentication provider associated with the specified
     * factory.
     *
     * - parameters:
     *     - fromFactory: The `AuthProviderClientFactory` which will provide the client for this authentication
     *                    provider. Each authentication provider that has extra functionality beyond logging in/linking
     *                    will offer a static factory which can be used for this method.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `fromFactory` parameter.
     */
    func providerClient<Factory: AuthProviderClientFactory>(fromFactory factory: Factory) -> Factory.ClientT where Factory.RequestClientT == StitchRequestClient

    /**
     * Retrieves the authenticated authentication provider client for the authentication provider associated with the
     * specified name and factory.
     *
     * - parameters:
     *     - fromFactory: The `NamedAuthProviderClientFactory` which will provide the client for this authentication
     *                    provider. Each named authentication provider that has extra functionality beyond
     *                    logging in/linking will offer a static factory which can be used for this method.
     *     - withName: The name of the authentication provider as defined in the MongoDB Stitch application.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `fromFactory` parameter.
     */
    func providerClient<Factory: NamedAuthProviderClientFactory>(fromFactory factory: Factory, withName name: String) -> Factory.Client

    // MARK: Authentication Actions

    /**
     * Authenticates the client as a MongoDB Stitch user using the provided `StitchCredential`.
     * On success, this user will become the active user.
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

    /**
     * Logs out the currently authenticated user, and clears any persisted authentication information.
     *
     * - parameters:
     *     - completionHandler: The completion handler to call when the logout is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func logout(_ completionHandler: @escaping (StitchResult<Void>) -> Void)

    /**
     * Logs out of the user with the given userId. The user must exist in the list of all
     * users who have logged into this application otherwise this will throw a StitchServiveError.
     *
     * - parameters:
     *     - userId: A String specifying the desired `userId`
     *     - completionHandler: The completion handler to call when the switch is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func logoutUser(withId userId: String, _ completionHandler: @escaping (StitchResult<Void>) -> Void)

    /**
     * Switches the active user to the user with the specified id. The user must
     * exist in the list of all users who have logged into this application, and
     * the user must be currently logged in, otherwise this will throw a
     * StitchServiveError.
     *
     * - parameters:
     *     - userId: A String specifying the desired `userId`
     */
    func switchToUser(withId userId: String) throws -> StitchUser

    /**
     * Removes the current active user from the list of all users
     * associated with this application. If there is no currently active user, then the
     * function will return with success.
     * Additionally, this method will clear all user data including any synchronized databases.
     *
     * - parameters:
     *     - completionHandler: The completion handler to call when the switch is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func removeUser(_ completionHandler: @escaping (StitchResult<Void>) -> Void)

    /**
     * Removes the user with the provided id from the list of all users
     * associated with this application. If the user was logged in, the user will
     * be logged out before being removed. The user must exist in the list of all
     * users who have logged into this application otherwise this will throw a StitchServiveError.
     * Additionally, this method will clear all user data including any synchronized databases.
     *
     * - parameters:
     *     - userId: A String specifying the desired `userId`
     *     - completionHandler: The completion handler to call when the switch is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func removeUser(withId userId: String, _ completionHandler: @escaping (StitchResult<Void>) -> Void)

    /**
     * Returns a list of all users who have logged into this application, with the exception of
     * those that have been removed manually and anonymous users who have logged
     * out. This list is guaranteed to be in the order that the users were added
     * to the application.
     *
     * - parameters:
     *     - completionHandler: The completion handler to call when the switch is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func listUsers() -> [StitchUser]

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

    func refreshCustomData(_ completionHandler: @escaping (StitchResult<Void>) -> Void)
    // swiftlint:enable line_length
}
