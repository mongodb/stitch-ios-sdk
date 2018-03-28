/** :nodoc: */
open class CoreFacebookAuthProviderClient {
    private let providerName: String

    public init(withProviderName providerName: String = "oauth2-facebook") {
        self.providerName = providerName
    }

    public func credential(withAccessToken accessToken: String) -> FacebookCredential {
        return FacebookCredential(withProviderName: providerName,
                                  withAccessToken: accessToken)
    }
}
