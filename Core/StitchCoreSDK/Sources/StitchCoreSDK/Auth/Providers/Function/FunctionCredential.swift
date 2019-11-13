import MongoSwift

/**
 * The `FunctionCredential` is a `StitchCredential` that can be used to log in
 * using the [Function Authentication Provider](https://docs.mongodb.com/stitch/authentication/function/).
 *
 * - SeeAlso:
 * `StitchAuth`
 */
public struct FunctionCredential: StitchCredential {
    // MARK: Initializer

    /**
     * Initializes this credential with the name of the provider.
     */
    public init(payload: Document, withProviderName providerName: String = providerType.name) {
        self.providerName = providerName
        self.material = payload
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
