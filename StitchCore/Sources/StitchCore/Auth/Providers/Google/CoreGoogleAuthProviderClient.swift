/**
 * :nodoc:
 * A client for the Google authentication provider which can be used to obtain a credential for logging in.
 */
open class CoreGoogleAuthProviderClient {
    /**
     * The name of the provider.
     */
    private let providerName: String

    /**
     * Initializes this provider client with the name of the provider.
     */
    public init(withProviderName providerName: String = "oauth2-google") {
        self.providerName = providerName
    }

    /**
     * Returns a credential for the provider, with the provided Google OAuth2 authentication code.
     */
    public func credential(withAuthCode authCode: String) -> GoogleCredential {
        return GoogleCredential.init(withProviderName: providerName,
                                     withAuthCode: authCode)
    }
}
