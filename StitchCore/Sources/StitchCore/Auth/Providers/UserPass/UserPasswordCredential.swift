import ExtendedJSON

/**
 * A credential which can be used to log in as a Stitch user
 * using the username/password authentication provider.
 */
public struct UserPasswordCredential: StitchCredential {
    /**
     * The name of the provider for this credential.
     */
    public var providerName: String

    /**
     * The type of the provider for this credential.
     */
    public var providerType: String = "local-userpass"

    /**
     * The contents of this credential as they will be passed to the Stitch server.
     */
    public var material: Document {
        return ["username": self.username,
                "password": self.password]
    }

    /**
     * The behavior of this credential when logging in.
     */
    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: false)

    /**
     * The username contained within this credential.
     */
    private let username: String

    /**
     * The password contained within this credential.
     */
    private let password: String

    /**
     * Initializes this credential with the name of the provider, the username of the user, and the password of the
     * user.
     */
    public init(withProviderName providerName: String = "local-userpass",
                withUsername username: String,
                withPassword password: String) {
        self.providerName = providerName
        self.username = username
        self.password = password
    }
}
