import ExtendedJSON

/**
 * :nodoc:
 * A credential which can be used to log in as a Stitch user
 * using the Custom authentication provider.
 */
public struct CustomCredential: StitchCredential {
    public var providerName: String

    public var providerType: String = "custom-token"

    public var material: Document {
        return ["token": self.token]
    }

    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: false)

    public let token: String

    public init(withProviderName providerName: String = "custom-token", withToken token: String) {
        self.providerName = providerName
        self.token = token
    }
}
