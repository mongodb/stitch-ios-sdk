/** :nodoc: */
open class CoreGoogleAuthProviderClient {
    private let providerName: String

    public init(withProviderName providerName: String = "oauth2-google") {
        self.providerName = providerName
    }

    public func credential(withAuthCode authCode: String) -> GoogleCredential {
        return GoogleCredential.init(withProviderName: providerName,
                                     withAuthCode: authCode)
    }
}
