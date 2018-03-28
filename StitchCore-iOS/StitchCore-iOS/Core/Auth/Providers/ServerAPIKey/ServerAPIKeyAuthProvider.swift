import Foundation
import StitchCore

/**
 * A utility class which contains a property that can be used with `StitchAuth` to retrieve a `ServerAPIKeyAuthProviderClient`.
 */
public final class ServerAPIKeyAuthProvider {
    
    /**
     * An `AuthProviderClientSupplier` which can be used with `StitchAuth` to retrieve a `ServerAPIKeyAuthProviderClient`.
     */
    public static let clientProvider: ClientProviderImpl = ClientProviderImpl.init()
    
    /**
     * :nodoc:
     * An implementation of `AuthProviderClientSupplier` that produces a `ServerAPIKeyAuthProviderClient`.
     */
    public final class ClientProviderImpl: AuthProviderClientSupplier {
        public typealias Client = ServerAPIKeyAuthProviderClient
        
        public func client(withRequestClient _: StitchRequestClient, withRoutes _: StitchAuthRoutes, withDispatcher _: OperationDispatcher) -> ServerAPIKeyAuthProviderClient {
            return CoreServerAPIKeyAuthProviderClient.init()
        }
    }
}

/**
 * A protocol that provides a method for getting a `StitchCredential` property
 * that can be used to log in with the Server API Key authentication provider.
 */
public protocol ServerAPIKeyAuthProviderClient {
    
    /**
     * Gets a credential that can be used to log in with the Server API Key authentication provider.
     *
     * - parameters:
     *     - forKey: The API key (as defined in the Stitch admin console) to authenticate with.
     * - returns: a credential conforming to `StitchCredential`
     */
    func credential(forKey key: String) -> ServerAPIKeyCredential
}

// Add conformance to ServerAPIKeyAuthProviderClient protocol
extension CoreServerAPIKeyAuthProviderClient: ServerAPIKeyAuthProviderClient { }
