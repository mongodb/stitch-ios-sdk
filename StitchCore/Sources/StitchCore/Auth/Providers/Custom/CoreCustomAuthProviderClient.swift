/**
 * :nodoc:
 * A client for the custom authentication provider which can be used to obtain a credential for logging in.
 */
open class CoreCustomAuthProviderClient {
    /**
     * The name of the provider.
     */
    private let providerName: String

    /**
     * Initializes this provider client with the name of the provider.
     */
    public init(withProviderName providerName: String = "custom-token") {
        self.providerName = providerName
    }

    /**
     * Returns a credential for the provider, with the provided JWT.
     */
    public func credential(withToken token: String) -> CustomCredential {
        return CustomCredential(withProviderName: providerName, withToken: token)
    }
}
