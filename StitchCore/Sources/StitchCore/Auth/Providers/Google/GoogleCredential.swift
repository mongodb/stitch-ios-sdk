import ExtendedJSON

/**
 * :nodoc:
 * A credential which can be used to log in as a Stitch user
 * using the Google authentication provider.
 */
public struct GoogleCredential: StitchCredential {
    public var providerName: String

    public var providerType: String = "oauth2-google"

    public var material: Document {
        return ["authCode": authCode]
    }

    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: false)

    private let authCode: String

    public init(withProviderName providerName: String = "oauth2-google",
                withAuthCode authCode: String) {
        self.providerName = providerName
        self.authCode = authCode
    }
}
