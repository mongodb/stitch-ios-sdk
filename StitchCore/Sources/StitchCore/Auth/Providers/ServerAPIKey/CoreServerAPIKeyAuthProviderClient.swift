/** :nodoc: */
open class CoreServerAPIKeyAuthProviderClient {
    private let providerName: String

    public init(withProviderName providerName: String = "api-key") {
        self.providerName = providerName
    }

    public func credential(forKey key: String) -> ServerAPIKeyCredential {
        return ServerAPIKeyCredential(withProviderName: self.providerName, withKey: key)
    }
}
