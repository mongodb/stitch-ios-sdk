/** :nodoc: */
open class CoreCustomAuthProviderClient {
    private let providerName: String

    public init(withProviderName providerName: String = "custom-token") {
        self.providerName = providerName
    }

    public func credential(withToken token: String) -> CustomCredential {
        return CustomCredential(withProviderName: providerName, withToken: token)
    }
}
