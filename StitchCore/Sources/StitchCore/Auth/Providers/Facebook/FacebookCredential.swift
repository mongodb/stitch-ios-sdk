import ExtendedJSON

/**
 * :nodoc:
 * A credential which can be used to log in as a Stitch user
 * using the Facebook authentication provider.
 */
public struct FacebookCredential: StitchCredential {
    public var providerName: String

    public var providerType: String = "oauth2-facebook"

    public var material: Document {
        return ["accessToken": self.accessToken]
    }

    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: false)

    private let accessToken: String

    public init(withProviderName providerName: String = "oauth2-facebook",
                withAccessToken accessToken: String) {
        self.providerName = providerName
        self.accessToken = accessToken
    }
}
