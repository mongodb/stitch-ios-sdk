import MongoSwift

/**
 * The `AppleCredential` is a `StitchCredential` that is used to log in
 * using the [Apple Authentication Provider](https://docs.mongodb.com/stitch/authentication/apple/).
 *
 * - SeeAlso:
 * `StitchAuth`
 */
public struct AppleCredential: StitchCredential {
    // MARK: Initializer

    /**
     * Initializes this credential with the name of the provider and a Apple OAuth2 identity token.
     */
    public init(withProviderName providerName: String = providerType.name,
                identityToken: Data) {
        self.providerName = providerName
        self.identityToken = String(data: identityToken, encoding: .utf8)!
    }

    // MARK: Properties

    /**
     * The name of the provider for this credential.
     */
    public var providerName: String

    /**
     * The type of the provider for this credential.
     */
    public static let providerType: StitchProviderType = .apple

    /**
     * The contents of this credential as they will be passed to the Stitch server.
     */
    public var material: Document {
        return ["id_token": identityToken]
    }

    /**
     * The behavior of this credential when logging in.
     */
    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: false)

    /**
     * The Apple OAuth2 identity token contained within this credential.
     */
    private let identityToken: String
}
