/**
 * :nodoc:
 * A client for the Facebook authentication provider which can be used to obtain a credential for logging in.
 */
open class CoreFacebookAuthProviderClient {
    /**
     * The name of the provider.
     */
    private let providerName: String

    /**
     * Initializes this provider client with the name of the provider.
     */
    public init(withProviderName providerName: String = "oauth2-facebook") {
        self.providerName = providerName
    }

    /**
     * Returns a credential for the provider, with the provided Facebook OAuth2 access token.
     */
    public func credential(withAccessToken accessToken: String) -> FacebookCredential {
        return FacebookCredential(withProviderName: providerName,
                                  withAccessToken: accessToken)
    }
}
