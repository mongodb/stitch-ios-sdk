import Foundation
import StitchCore

private enum ConfigKeys: String, CodingKey {
    case type, config
}

private enum CustomTokenCodingKeys: String, CodingKey {
    case signingKey
}

private enum UserpassCodingKeys: String, CodingKey {
    case emailConfirmationUrl
    case resetPasswordUrl
    case confirmEmailSubject
    case resetPasswordSubject
}

enum ProviderConfigs: Encodable {
    case anon()
    case userpass(emailConfirmationUrl: String,
                  resetPasswordUrl: String,
                  confirmEmailSubject: String,
                  resetPasswordSubject: String)
    case custom(signingKey: String)

    var type: AuthProviderTypes {
        switch self {
        case .anon(): return .anonymous
        case .userpass(_): return .emailPass
        case .custom(_): return .custom
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ConfigKeys.self)
        try container.encode(self.type, forKey: .type)
        switch self {
        case .anon(): break
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
