import MongoSwift

/**
 * The `GoogleCredential` is a `StitchCredential` that is used to log in
 * using the [Google Authentication Provider](https://docs.mongodb.com/stitch/authentication/google/).
 *
 * - SeeAlso:
 * `StitchAuth`
 */
public struct GoogleCredential: StitchCredential {
    // MARK: Initializer

    /**
     * Initializes this credential with the name of the provider and a Google OAuth2 authentication code.
     */
    public init(withProviderName providerName: String = providerType.name,
                withAuthCode authCode: String) {
        self.providerName = providerName
        self.authCode = authCode
    }

    // MARK: Properties

    /**
     * The name of the provider for this credential.
     */
    public var providerName: String

    /**
     * The type of the provider for this credential.
     */
    public static let providerType: StitchProviderType = .google

    /**
     * The contents of this credential as they will be passed to the Stitch server.
     */
    public var material: Document {
        return ["authCode": authCode]
    }

    /**
     * The behavior of this credential when logging in.
     */
    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: false)

    /**
     * The Google OAuth2 authentication code contained within this credential.
     */
    private let authCode: String
}
