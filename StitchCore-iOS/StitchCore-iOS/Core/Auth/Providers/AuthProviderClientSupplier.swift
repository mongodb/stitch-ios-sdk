import Foundation
import StitchCore

/**
 * A protocol defining methods necessary to provide an authentication provider client.
 * This protocol is not to be inherited except internally within the StitchCore-iOS module.
 */
public protocol AuthProviderClientSupplier {
    /**
     * The type of client that this supplier will supply.
     */
    associatedtype ClientT

    /**
     * The type of request client that this auth provider client will use under the hood.
     */
    associatedtype RequestClientT

    /**
     * :nodoc:
     * Returns the client that this `AuthProviderClientSupplier` supplies. If the client will be making requests,
     * it will use the provided `StitchRequestClient`, `StitchAuthRoutes`, and `OperationDispatcher` to perform those
     * requests.
     */
    func client(withRequestClient requestClient: RequestClientT,
                withRoutes routes: StitchAuthRoutes,
                withDispatcher dispatcher: OperationDispatcher) -> ClientT
}
