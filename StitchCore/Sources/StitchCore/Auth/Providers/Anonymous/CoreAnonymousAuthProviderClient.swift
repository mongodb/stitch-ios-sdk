/**
 * :nodoc:
 * A client for the anonymous authentication provider which can be used to obtain a credential for logging in.
 */
open class CoreAnonymousAuthProviderClient {
    /**
     * The name of the provider.
     */
    private let providerName: String

    /**
     * Returns a credential for the provider.
     */
    public lazy var credential = AnonymousCredential(withProviderName: providerName)

    /**
     * Initializes this provider client with the name of the provider.
     */
    public init(providerName: String = "anon-user") {
        self.providerName = providerName
    }
}
