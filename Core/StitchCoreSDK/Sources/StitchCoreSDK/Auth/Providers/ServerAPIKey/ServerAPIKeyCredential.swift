import MongoSwift

/**
 * A credential which can be used to log in as a Stitch user
 * using the Server API Key authentication provider.
 */
public struct ServerAPIKeyCredential: StitchCredential {
    // MARK: Initializer
    
    /**
     * Initializes this credential with the name of the provider, and a server API key.
     */
    public init(withProviderName providerName: String = providerType.name,
                withKey key: String) {
        self.providerName = providerName
        self.key = key
    }

    // MARK: Properties
    
    /**
     * The name of the provider for this credential.
     */
    public var providerName: String

    /**
     * The type of the provider for this credential.
     */
    public static let providerType: StitchProviderType = .serverAPIKey

    /**
     * The contents of this credential as they will be passed to the Stitch server.
     */
    public var material: Document {
        return ["key": self.key]
    }

    /**
     * The behavior of this credential when logging in.
     */
    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: false)

    /**
     * The server API key contained within this credential.
     */
    public let key: String
}
