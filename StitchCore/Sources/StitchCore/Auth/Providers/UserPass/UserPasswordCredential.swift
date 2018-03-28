import ExtendedJSON

/**
 * :nodoc:
 * A credential which can be used to log in as a Stitch user
 * using the username/password authentication provider.
 */
public struct UserPasswordCredential: StitchCredential {
    public var providerName: String

    public var providerType: String = "local-userpass"

    public var material: Document {
        return ["username": self.username,
                "password": self.password]
    }

    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: false)

    private let username: String
    private let password: String

    public init(withProviderName providerName: String = "local-userpass",
                withUsername username: String,
                withPassword password: String) {
        self.providerName = providerName
        self.username = username
        self.password = password
    }
}
