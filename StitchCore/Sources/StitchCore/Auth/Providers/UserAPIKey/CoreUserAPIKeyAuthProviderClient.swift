/**
 * :nodoc:
 * A client for the user API key authentication provider which can be used to obtain a credential for logging in.
 */
open class CoreUserAPIKeyAuthProviderClient {
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
     * Returns a credential for the provider, with the provided user API key.
     */
    public func credential(forKey key: String) -> UserAPIKeyCredential {
        return UserAPIKeyCredential(withProviderName: self.providerName, withKey: key)
    }
}
