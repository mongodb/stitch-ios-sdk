import MongoSwift

/**
 * A credential which can be used to log in as a Stitch user
 * using the anonymous authentication provider.
 */
public struct AnonymousCredential: StitchCredential {
    // MARK: Initializer
    
    /**
     * Initializes this credential with the name of the provider.
     */
    public init(withProviderName providerName: String = providerType.name) {
        self.providerName = providerName
    }
    
    // MARK: Properties
    
    /**
     * The name of the provider for this credential.
     */
    public var providerName: String

    /**
     * The type of the provider for this credential.
     */
    public static let providerType: StitchProviderType = .anonymous

    /**
     * The contents of this credential as they will be passed to the Stitch server.
     */
    public var material: Document = [:]

    /**
     * The behavior of this credential when logging in.
     */
    public var providerCapabilities: ProviderCapabilities = ProviderCapabilities.init(reusesExistingSession: true)
}
