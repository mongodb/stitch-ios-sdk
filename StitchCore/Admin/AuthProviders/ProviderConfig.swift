import Foundation

/// Base keys for a provider configuration
private enum ConfigKeys: String, CodingKey {
    case type, config
}

/// Key for the `custom-token` provider configuration
private enum CustomTokenCodingKeys: String, CodingKey {
    case signingKey
}

/// Keys for the `local-userpass` provider configuration
private enum UserpassCodingKeys: String, CodingKey {
    case emailConfirmationUrl
    case resetPasswordUrl
    case confirmEmailSubject
    case resetPasswordSubject
}

/// Convenience enum for creating a new provider config. Given that there
/// are only a finite number of providers, this conforms users
/// to only pick one of the available providers
public enum ProviderConfigs: Encodable {
    case anon()
    /// - parameter emailConfirmationUrl: url to redirect user to for email confirmation
    /// - parameter resetPasswordUrl: url to redirect user to for password reset
    /// - parameter confirmEmailSubject: subject of the email to confirm a new user
    /// - parameter resetPasswordSubject: subject of the email to reset a password
    case userpass(emailConfirmationUrl: String,
                  resetPasswordUrl: String,
                  confirmEmailSubject: String,
                  resetPasswordSubject: String)
    /// - parameter signingKey: key used to sign a JWT for `custom-token`
    case custom(signingKey: String)

    private var type: StitchProviderType {
        switch self {
        case .anon: return .anonymous
        case .userpass: return .userPassword
        case .custom: return .custom
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ConfigKeys.self)
        try container.encode(self.type.name, forKey: .type)
        switch self {
        case .anon: break
        case .userpass(let emailConfirmationUrl,
                       let resetPasswordUrl,
                       let confirmEmailSubject,
                       let resetPasswordSubject):
            var configContainer = container.nestedContainer(keyedBy: UserpassCodingKeys.self,
                                                            forKey: .config)
            try configContainer.encode(emailConfirmationUrl, forKey: .emailConfirmationUrl)
            try configContainer.encode(resetPasswordUrl, forKey: .resetPasswordUrl)
            try configContainer.encode(confirmEmailSubject, forKey: .confirmEmailSubject)
            try configContainer.encode(resetPasswordSubject, forKey: .resetPasswordSubject)
        case .custom(let signingKey):
            var configContainer = container.nestedContainer(keyedBy: CustomTokenCodingKeys.self,
                                                            forKey: .config)
            try configContainer.encode(signingKey, forKey: .signingKey)
        }
    }
}
