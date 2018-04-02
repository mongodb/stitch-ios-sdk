import Foundation
import StitchCore

/**
 * A utility class which contains a property that can be used with `StitchAuth` to retrieve a
 * `CustomAuthProviderClient`.
 */
public final class CustomAuthProvider {

    /**
     * An `AuthProviderClientSupplier` which can be used with `StitchAuth` to retrieve an `CustomAuthProviderClient`.
     */
    public static let clientProvider: ClientProviderImpl = ClientProviderImpl.init()

    /**
     * :nodoc:
     * An implementation of `AuthProviderClientSupplier` that produces a `CustomAuthProviderClient`.
     */
    public final class ClientProviderImpl: AuthProviderClientSupplier {
        public typealias Client = CustomAuthProviderClient

        public func client(withRequestClient _: StitchRequestClient,
                           withRoutes _: StitchAuthRoutes,
                           withDispatcher _: OperationDispatcher) -> CustomAuthProviderClient {
            return CoreCustomAuthProviderClient.init()
        }
    }
}

/**
 * A protocol that provides a method for getting a `StitchCredential` property
 * that can be used to log in with the custom authentication provider.
 */
public protocol CustomAuthProviderClient {

    /**
     * Gets a credential that can be used to log in with the custom authentication provider.
     *
     * - parameters:
     *     - withToken: The JWT to use to authenticate with the custom authentication provider.
     * - returns: a credential conforming to `StitchCredential`
     */
    func credential(withToken token: String) -> CustomCredential
}

// Add conformance to CustomAuthProviderClient protocol
extension CoreCustomAuthProviderClient: CustomAuthProviderClient { }
