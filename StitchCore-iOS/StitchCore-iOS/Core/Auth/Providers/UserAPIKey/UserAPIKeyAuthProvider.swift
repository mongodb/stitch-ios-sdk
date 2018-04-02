import Foundation
import StitchCore

/**
 * A utility class which contains a property that can be used with `StitchAuth` to retrieve a
 * `UserAPIKeyAuthProviderClient`.
 */
public final class UserAPIKeyAuthProvider {
    /**
     * An `AuthProviderClientSupplier` which can be used with `StitchAuth` to retrieve an
     * `UserAPIKeyAuthProviderClient`.
     */
    public static let clientSupplier: ClientSupplierImpl = ClientSupplierImpl.init()

    /**
     * :nodoc:
     * An implementation of `AuthProviderClientSupplier` that produces a `UserAPIKeyAuthProviderClient`.
     */
    public final class ClientSupplierImpl: AuthProviderClientSupplier {
        public typealias Client = UserAPIKeyAuthProviderClient

        public func client(withRequestClient _: StitchRequestClient,
                           withRoutes _: StitchAuthRoutes,
                           withDispatcher _: OperationDispatcher) -> UserAPIKeyAuthProviderClient {
            return CoreUserAPIKeyAuthProviderClient.init()
        }
    }
}

/**
 * A protocol that provides a method for getting a `StitchCredential` property
 * that can be used to log in with the User API Key authentication provider.
 */
public protocol UserAPIKeyAuthProviderClient {
    /**
     * Gets a credential that can be used to log in with the User API Key authentication provider.
     *
     * - parameters:
     *     - forKey: The API key (as created by a Stitch user) to authenticate with.
     * - returns: a credential conforming to `StitchCredential`
     */
    func credential(forKey key: String) -> UserAPIKeyCredential
}

// Add conformance to ServerAPIKeyAuthProviderClient protocol
extension CoreUserAPIKeyAuthProviderClient: UserAPIKeyAuthProviderClient { }
