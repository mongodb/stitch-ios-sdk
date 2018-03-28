import Foundation
import StitchCore

/**
 * A utility class which contains a property that can be used with `StitchAuth` to retrieve a
 * `GoogleAuthProviderClient`.
 */
public final class GoogleAuthProvider {
    /**
     * An `AuthProviderClientSupplier` which can be used with `StitchAuth` to retrieve an `GoogleAuthProviderClient`.
     */
    public static let clientProvider: ClientProviderImpl = ClientProviderImpl.init()

    /**
     * :nodoc:
     * An implementation of `AuthProviderClientSupplier` that produces a `GoogleAuthProviderClient`.
     */
    public final class ClientProviderImpl: AuthProviderClientSupplier {
        public typealias Client = GoogleAuthProviderClient

        public func client(withRequestClient _: StitchRequestClient,
                           withRoutes _: StitchAuthRoutes,
                           withDispatcher _: OperationDispatcher) -> GoogleAuthProviderClient {
            return CoreGoogleAuthProviderClient.init()
        }
    }
}

/**
 * A protocol that provides a method for getting a `StitchCredential` property
 * that can be used to log in with the Google authentication provider.
 */
public protocol GoogleAuthProviderClient {
    /**
     * Gets a credential that can be used to log in with the Google authentication provider.
     *
     * - parameters:
     *     - withAuthCode: The authentication code retrieved from the Google Sign-In SDK for Swift.
     * - returns: a credential conforming to `StitchCredential`
     */
    func credential(withAuthCode authCode: String) -> GoogleCredential
}

// Add conformance to GoogleAuthProviderClient protocol
extension CoreGoogleAuthProviderClient: GoogleAuthProviderClient { }
