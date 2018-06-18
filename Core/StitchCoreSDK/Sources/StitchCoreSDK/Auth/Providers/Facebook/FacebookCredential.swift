import MongoSwift

/**
 * A credential which can be used to log in as a Stitch user
 * using the Facebook authentication provider.
 */
public struct FacebookCredential: StitchCredential {
    // MARK: Initializer
    
    /**
     * Initializes this credential with the name of the provider, and a Facebook OAuth2 access token.
     */
    public init(withProviderName providerName: String = providerType.name,
                withAccessToken accessToken: String) {
        self.providerName = providerName
        self.accessToken = accessToken
    }

    // MARK: Properties
    
    /**
     * The name of the provider for this credential.
     */
    public var providerName: String

    /**
     * The type of the provider for this credential.
     */
    public static let providerType: StitchProviderType = .facebook

    /**
     * The contents of this credential as they will be passed to the Stitch server.
     */
    public var material: Document {
        return ["accessToken": self.accessToken]
    }

    /**
     * The behavior of this credential when logging in.
     */
    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: false)

    /**
     * The Facebook OAuth2 access token contained within this credential.
     */
    private let accessToken: String
}
