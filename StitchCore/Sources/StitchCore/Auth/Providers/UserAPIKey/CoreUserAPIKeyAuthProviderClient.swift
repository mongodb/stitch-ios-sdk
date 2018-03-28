/** :nodoc: */
open class CoreUserAPIKeyAuthProviderClient {
    private let providerName: String

    public init(withProviderName providerName: String = "api-key") {
        self.providerName = providerName
    }

    public func credential(forKey key: String) -> UserAPIKeyCredential {
        return UserAPIKeyCredential(withProviderName: self.providerName, withKey: key)
    }
}
