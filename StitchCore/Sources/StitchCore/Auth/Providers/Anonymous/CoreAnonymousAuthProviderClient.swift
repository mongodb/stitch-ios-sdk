/** :nodoc: */
open class CoreAnonymousAuthProviderClient {
    private let providerName: String

    public lazy var credential = AnonymousCredential(withProviderName: providerName)

    public init(providerName: String = "anon-user") {
        self.providerName = providerName
    }
}
