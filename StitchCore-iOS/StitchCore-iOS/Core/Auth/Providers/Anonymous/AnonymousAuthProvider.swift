import Foundation
import StitchCore

/**
 * A utility class which contains a property that can be used with `StitchAuth` to retrieve an
 * `AnonymousAuthProviderClient`.
 */
public final class AnonymousAuthProvider {
    /**
     * An `AuthProviderClientSupplier` which can be used with `StitchAuth` to retrieve an `AnonymousAuthProviderClient`.
     */
    public static let clientProvider: ClientProviderImpl = ClientProviderImpl.init()

    /**
     * :nodoc:
     * An implementation of `AuthProviderClientSupplier` that produces an `AnonymousAuthProviderClient`.
     */
    public final class ClientProviderImpl: AuthProviderClientSupplier {
        public typealias Client = AnonymousAuthProviderClient

        public func client(withRequestClient _: StitchRequestClient,
                           withRoutes _: StitchAuthRoutes,
                           withDispatcher _: OperationDispatcher) -> AnonymousAuthProviderClient {
            return CoreAnonymousAuthProviderClient.init()
        }
    }
}

/**
 * A protocol that provides a `StitchCredential` property that can be used to log in as an anonymous user.
 */
public protocol AnonymousAuthProviderClient {

    /**
     * A `StitchCredential` that can be used to log in as an anonymous user.
     */
    var credential: AnonymousCredential { get }
}

// :nodoc: Add conformance to AnonymousAuthProviderClient protocol
extension CoreAnonymousAuthProviderClient: AnonymousAuthProviderClient { }
