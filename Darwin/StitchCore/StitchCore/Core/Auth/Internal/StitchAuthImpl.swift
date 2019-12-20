import MongoSwift
import StitchCoreSDK
import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

/**
 * The implementation of `StitchAuth`, which holds and manages the authentication state of a Stitch client.
 */
internal final class StitchAuthImpl: CoreStitchAuth<StitchUserImpl>, StitchAuth {
    // MARK: Private Properties

    /**
     * The operation dispatcher used to dispatch asynchronous operations made by this client and its underlying
     * objects.
     */
    internal let dispatcher: OperationDispatcher

    /**
     * A `StitchAppClientInfo` describing the basic properties of the app client holding this `StitchAuthImpl.
     */
    private let appInfo: StitchAppClientInfo

    /**
     A list of weak references to `StitchAuthDelegate`,
     each of which will be notified asynchr when authentication events
     occur.
     */
    internal var delegates: [AnyStitchAuthDelegate] = []

    /**
     A list of weak references to `StitchAuthDelegate`
     each of which will be notified syncronously when authentication events
     occur.
     */
    internal var synchronousDelegates: [AnyStitchAuthDelegate] = []

    /**
     * Initializes this `StitchAuthImpl` with a request client, authentication API routes, a `Storage` for persisting
     * authentication information, an `OperationDispatcher` for dispatching asynchronous operations, and a
     * `StitchAppClientInfo` containing information about the app client that will hold this `StitchAuthImpl`.
     */
    public init(
        requestClient: StitchRequestClient,
        authRoutes: StitchAuthRoutes,
        storage: Storage,
        dispatcher: OperationDispatcher,
        appInfo: StitchAppClientInfo) throws {

        self.dispatcher = dispatcher
        self.appInfo = appInfo
        try super.init(requestClient: requestClient, authRoutes: authRoutes, storage: storage)
    }

    // MARK: Authentication Provider Clients

    /**
     * Retrieves the authenticated authentication provider client associated with the authentication provider type
     * specified in the argument.
     *
     * - parameters:
     *     - fromFactory: The authentication provider conforming to `AuthProviderClientFactory` which
     *                    will provide the client for this authentication provider. Use the `clientFactory` field of
     *                    the desired authentication provider class.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `fromFactory` parameter.
     * - throws: A Stitch client error if the client is not currently authenticated.
     */
    func providerClient<Factory: AuthProviderClientFactory>(fromFactory factory: Factory)
        -> Factory.ClientT where Factory.RequestClientT == StitchAuthRequestClient {
        return factory.client(withRequestClient: self,
                              withRoutes: self.authRoutes,
                              withDispatcher: self.dispatcher)
    }

    /**
     * Retrieves the authentication provider client associated with the authentication provider type specified in the
     * argument.
     *
     * - parameters:
     *     - fromFactory: The authentication provider conforming to `AuthProviderClientFactory` which will provide the
     *                    client for this authentication provider. Use the `clientFactory` field of the desired
     *                    authentication provider class.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `fromFactory` parameter.
     */
    func providerClient<Factory: AuthProviderClientFactory>(fromFactory factory: Factory)
        -> Factory.ClientT where Factory.RequestClientT == StitchRequestClient {
        return factory.client(withRequestClient: self.requestClient,
                              withRoutes: self.authRoutes,
                              withDispatcher: self.dispatcher)
    }

    /**
     * Retrieves the authentication provider client associated with the authentication provider with the specified name
     * and type.
     *
     * - parameters:
     *     - fromFactory: The authentication provider conforming to `NamedAuthProviderClientFactory` which will
     *                    provide the client for this authentication provider. Use the `namedClientFactory` field of
     *                    the desired authentication provider class.
     *     - withName: The name of the authentication provider as defined in the MongoDB Stitch application.
     * - returns: an authentication provider client whose type is determined by the `Client` typealias in the type
     *            specified in the `fromFactory` parameter.
     */
    public func providerClient<Factory>(fromFactory factory: Factory, withName name: String)
        -> Factory.Client where Factory: NamedAuthProviderClientFactory {
        return factory.client(forProviderName: name,
                               withRequestClient: self.requestClient,
                               withRoutes: self.authRoutes,
                               withDispatcher: self.dispatcher)
    }

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
    public func login(withCredential credential: StitchCredential,
                      _ completionHandler: @escaping (StitchResult<StitchUser>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.loginInternal(withCredential: credential)
        }
    }

    /**
     * Logs out the currently authenticated user, and clears any persisted authentication information.
     *
     * - parameters:
     *     - completionHandler: The completion handler to call when the logout is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    public func logout(_ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.logoutInternal(withID: nil)
        }
    }

    /**
     * Logs out of the user with the given userId. The user must exist in the list of all
     * users who have logged into this application otherwise this will throw a StitchServiveError.
     *
     * - parameters:
     *     - userId: A String specifying the desired `userId`
     *     - completionHandler: The completion handler to call when the switch is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    public func logoutUser(withId userId: String,
                           _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.logoutInternal(withID: userId)
        }
    }

    /**
     * Switches the active user to the user with the specified id. The user must
     * exist in the list of all users who have logged into this application, and
     * the user must be currently logged in, otherwise this will throw a
     * StitchServiveError.
     *
     * - parameters:
     *     - userId: A String specifying the desired `userId`
     */
    public func switchToUser(withId userId: String) throws -> StitchUser {
        return try self.switchToUserInternal(withID: userId)
    }

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
    public func removeUser(_ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.removeUserInternal(withID: nil)
        }
    }

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
    public func removeUser(withId userId: String,
                           _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.removeUserInternal(withID: userId)
        }
    }

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
    public func listUsers() -> [StitchUser] {
        return self.listUsersInternal()
    }

    /**
     * Links the currently authenticated user with a new identity, where the identity is defined by the credential
     * specified as a parameter. This will only be successful if this `StitchUser` is the currently authenticated
     * `StitchUser` for the client from which it was created.
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
    internal func link(withCredential credential: StitchCredential,
                       withUser user: StitchUserImpl,
                       _ completionHandler: @escaping (StitchResult<StitchUser>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.linkUserInternal(withUser: user, withCredential: credential)
        }
    }

    // MARK: Computed Properties

    /**
     * A user factory capable of producing `StitchUserImpl` objects that represent the user currently authenticated
     * by this `StitchAuthImpl`
     */
    public final override var userFactory: AnyStitchUserFactory<StitchUserImpl> {
        return AnyStitchUserFactory.init(stitchUserFactory: StitchUserFactoryImpl.init(withAuth: self))
    }

    /**
     * A `StitchUser` object representing the user that the client is currently authenticated as.
     * `nil` if the client is not currently authenticated.
     */
    public final var currentUser: StitchUser? {
        return self.user
    }

    /**
     * A BSON document containing information about the current device such as device id, local app name and version,
     * platform and platform version, and the current version of the Stitch SDK.
     */
    public final override var deviceInfo: Document {
        var info = Document.init()

        if self.hasDeviceID, let deviceID = self.deviceID {
            info[DeviceField.deviceID.rawValue] = deviceID
        }

        info[DeviceField.appID.rawValue] = self.appInfo.localAppName
        info[DeviceField.appVersion.rawValue] = self.appInfo.localAppVersion

        #if os(iOS) || os(tvOS)
        info[DeviceField.platform.rawValue] = UIDevice.current.systemName
        #elseif os(watchOS)
        info[DeviceField.platform.rawValue] = WKInterfaceDevice.current().systemName
        #else
        info[DeviceField.platform.rawValue] = ProcessInfo.processInfo.processName
        #endif
        info[DeviceField.platformVersion.rawValue] =
            "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)." +
            "\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)"
        info[DeviceField.sdkVersion.rawValue] = Stitch.sdkVersion

        return info
    }

    // MARK: Observer Delegates

    /**
     * Dispatches the appropriate auth event method of each registered `StitchAuthDelegate`.
     *
     * - important: This is not meant to be invoked directly in this class. The `CoreStitchAuth` from which this
     *              class inherits will call this method when appropraite.
     */
    public final override func dispatchAuthEvent(_ authEvent: AuthRebindEvent) {
        // NOTE: this function is in this file rather than the +Delegation file because Swift does not support
        //       overriding functions in extensions
        for (idx, delegateRef) in self.synchronousDelegates.enumerated().reversed() {
            guard let delegate = delegateRef.reference else {
                self.delegates.remove(at: idx)
                return
            }

            self.dispatch(authEvent: authEvent, toDelegate: delegate)
        }

        for (idx, delegateRef) in self.delegates.enumerated().reversed() {
            guard let delegate = delegateRef.reference else {
                self.delegates.remove(at: idx)
                return
            }

            // If this StitchAuth was deallocated, then this event should not be dispatched
            dispatcher.queue.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.dispatch(authEvent: authEvent, toDelegate: delegate)
            }
        }
    }

    public func refreshCustomData(_ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler, {
            try self.refreshAccessToken()
        })
    }
}
