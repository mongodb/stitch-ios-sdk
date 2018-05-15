import Foundation
import StitchCore

/**
 * A protocol defining methods necessary to provide an authenticated authentication provider client.
 * This protocol is not to be inherited except internally within the StitchCore-iOS module.
 */
public protocol AuthenticatedAuthProviderClientSupplier {
    /**
     * The type of client that this supplier will supply.
     */
    associatedtype Client

    /**
     * :nodoc:
     * Returns the client that this `AuthProviderClientSupplier` supplies. If the client will be making requests,
     * it will use the provided `StitchRequestClient`, `StitchAuthRoutes`, and `OperationDispatcher` to perform those
     * requests.
     */
    func client(withAuthRequestClient authRequestClient: StitchAuthRequestClient,
                withRoutes routes: StitchAuthRoutes,
                withDispatcher dispatcher: OperationDispatcher) -> Client
}
