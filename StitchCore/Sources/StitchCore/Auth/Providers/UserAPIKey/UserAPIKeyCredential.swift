import ExtendedJSON

/**
 * :nodoc:
 * A credential which can be used to log in as a Stitch user
 * using the User API Key authentication provider.
 */
public struct UserAPIKeyCredential: StitchCredential {
    public var providerName: String

    public var providerType: String = "api-key"

    public var material: Document {
        return ["key": key]
    }

    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: false)

    public let key: String

    internal init(withProviderName providerName: String = "api-key",
                  withKey key: String) {
        self.providerName = providerName
        self.key = key
    }
}
