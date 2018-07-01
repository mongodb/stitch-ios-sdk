import Foundation
import StitchCoreSDK

/**
 * A protocol defining methods necessary to provide an authentication provider client for a named authentication
 * provider. This protocol is not to be inherited except internally within the StitchCore-iOS module. Each named
 * authentication provider with a client offers a static factory implementing this protocol.
 */
public protocol NamedAuthProviderClientFactory {
    /**
     * The type of client that this factory will supply.
     */
    associatedtype Client

    /**
     * :nodoc:
     * Returns the client that this `NamedAuthProviderClientFactory` supplies. If the client will be making requests,
     * it will use the provided `StitchRequestClient`, `StitchAuthRoutes`, and `OperationDispatcher` to perform those
     * requests, and it will make those requests for the authentication provider with the provided name.
     */
    func client(forProviderName providerName: String,
                withRequestClient requestClient: StitchRequestClient,
                withRoutes routes: StitchAuthRoutes,
                withDispatcher dispatcher: OperationDispatcher) -> Client
}
