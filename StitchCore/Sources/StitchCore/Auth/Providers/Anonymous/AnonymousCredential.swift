import ExtendedJSON

/**
 * :nodoc:
 * A credential which can be used to log in as a Stitch user
 * using the anonymous authentication provider.
 */
public struct AnonymousCredential: StitchCredential {
    public var providerName: String

    public var providerType: String = "anon-user"

    public var material: Document = [:]

    public var providerCapabilities: ProviderCapabilities =
        ProviderCapabilities.init(reusesExistingSession: true)

    public init(withProviderName providerName: String = "anon-user") {
        self.providerName = providerName
    }
}
