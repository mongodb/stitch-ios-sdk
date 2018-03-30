/**
 * :nodoc:
 * A client for the server API key authentication provider which can be used to obtain a credential for logging in.
 */
open class CoreServerAPIKeyAuthProviderClient {
    /**
     * The name of the provider.
     */
    private let providerName: String

    /**
     * Initializes this provider client with the name of the provider.
     */
    public init(withProviderName providerName: String = "api-key") {
        self.providerName = providerName
    }

    /**
     * Returns a credential for the provider, with the provided server API key.
     */
    public func credential(forKey key: String) -> ServerAPIKeyCredential {
        return ServerAPIKeyCredential(withProviderName: self.providerName, withKey: key)
    }
}
