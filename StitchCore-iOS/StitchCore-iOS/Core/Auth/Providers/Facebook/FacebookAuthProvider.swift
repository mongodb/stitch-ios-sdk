import Foundation
import StitchCore

/**
 * A utility class which contains a property that can be used with `StitchAuth` to retrieve a `FacebookAuthProviderClient`.
 */
public final class FacebookAuthProvider {
    
    /**
     * An `AuthProviderClientSupplier` which can be used with `StitchAuth` to retrieve an `FacebookAuthProviderClient`.
     */
    public static let clientProvider: ClientProviderImpl = ClientProviderImpl.init()
    
    /**
     * :nodoc:
     * An implementation of `AuthProviderClientSupplier` that produces a `FacebookAuthProviderClient`.
     */
    public final class ClientProviderImpl: AuthProviderClientSupplier {
        public typealias Client = FacebookAuthProviderClient
        
        public func client(withRequestClient _: StitchRequestClient, withRoutes _: StitchAuthRoutes, withDispatcher _: OperationDispatcher) -> FacebookAuthProviderClient {
            return CoreFacebookAuthProviderClient.init()
        }
    }
}

/**
 * A protocol that provides a method for getting a `StitchCredential` property
 * that can be used to log in with the Facebook authentication provider.
 */
public protocol FacebookAuthProviderClient {
    
    /**
     * Gets a credential that can be used to log in with the Facebook authentication provider.
     *
     * - parameters:
     *     - withAccessToken: The access token retrieved from the Facebook Login SDK for Swift.
     * - returns: a credential conforming to `StitchCredential`
     */
    func credential(withAccessToken accessToken: String) -> FacebookCredential
}

// Add conformance to FacebookAuthProviderClient protocol
extension CoreFacebookAuthProviderClient: FacebookAuthProviderClient { }
