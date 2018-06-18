import MongoSwift

/**
 * A credential which can be used to log in as a Stitch user
 * using the Custom authentication provider.
 */
public struct CustomCredential: StitchCredential {
    // MARK: Initializer
    
    /**
     * Initializes this credential with the name of the provider, and a JWT.
     */
    public init(withProviderName providerName: String = providerType.name, withToken token: String) {
        self.providerName = providerName
        self.token = token
    }

    // MARK: Properties
    
    /**
     * The name of the provider for this credential.
     */
    public var providerName: String

    /**
     * The type of the provider for this credential.
     */
    public static let providerType: StitchProviderType = .custom

    /**
     * The contents of this credential as they will be passed to the Stitch server.
     */
    public var material: Document {
        return ["token": self.token]
    }

    /**
     * The behavior of this credential when logging in.
     */
    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: false)

    /**
     * The JWT contained within this credential.
     */
    public let token: String
}
