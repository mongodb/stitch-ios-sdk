import Foundation
import ExtendedJson

public protocol AuthProviderType: Codable {
    var id: String { get }
    var name: String { get }
    var type: String { get }
    var disabled: Bool { get }
}

public struct AnonymousAuthProviderInfo: AuthProviderType {
    public let id: String
    public let name: String
    public let type: String
    public let disabled: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id", name, type, disabled
    }
}
public struct EmailPasswordAuthProviderInfo: AuthProviderType {
    struct Config: Codable {
        let emailConfirmationUrl: String
        let resetPasswordUrl: String
    }

    let config: Config
    public let id: String
    public let name: String
    public let type: String
    public let disabled: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id", name, type, disabled, config
    }
}
public struct ApiKeyAuthProviderInfo: AuthProviderType {
    public let id: String
    public let name: String
    public let type: String
    public let disabled: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id", name, type, disabled
    }
}
public struct GoogleAuthProviderInfo: AuthProviderType {
    struct Config: Codable {
        let clientId: String
    }
    struct MetadataField: Codable {
        let name: String
        let required: Bool
    }

    let config: Config
    let metadataFields: [MetadataField]?

    public let id: String
    public let name: String
    public let type: String
    public let disabled: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id", metadataFields = "metadata_fields", name, type, disabled, config
    }
}
public struct FacebookAuthProviderInfo: AuthProviderType {
    struct Config: Codable {
        let clientId: String
    }
    struct MetadataField: Codable {
        let name: String
        let required: Bool
    }

    let config: Config
    let metadataFields: [MetadataField]?
    public let id: String
    public let name: String
    public let type: String
    public let disabled: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id", name, type, disabled, config, metadataFields = "metadata_fields"
    }
}

private enum AuthProviderTypes: String {
    case google = "oauth2-google"
    case facebook = "oauth2-facebook"
    case apiKey = "api-key"
    case emailPass = "local-userpass"
    case anonymous = "anon-user"
}

/// Struct containing information about available providers
public struct AuthProviderInfo {
    /// Info about the `AnonymousAuthProvider`
    public private(set) var anonymousAuthProviderInfo: AnonymousAuthProviderInfo?
    /// Info about the `GoogleAuthProvider`
    public private(set) var googleProviderInfo: GoogleAuthProviderInfo?
    /// Info about the `FacebookAuthProvider`
    public private(set) var facebookProviderInfo: FacebookAuthProviderInfo?
    /// Info about the `EmailPasswordAuthProvider`
    public private(set) var emailPasswordAuthProviderInfo: EmailPasswordAuthProviderInfo?
    /// Info about the `ApiKeyAuthProvider`
    public private(set) var apiKeyAuthProviderInfo: ApiKeyAuthProviderInfo?

    public init(from infos: [[String: Any]]) throws {
        try infos.forEach { info in
            guard let type = info["type"] as? String,
                let providerType = AuthProviderTypes.init(rawValue: type) else {
                return
            }

            let data = try JSONSerialization.data(withJSONObject: info)
            switch providerType {
            case .google: googleProviderInfo =
                try JSONDecoder().decode(GoogleAuthProviderInfo.self, from: data)
            case .facebook: facebookProviderInfo =
                try JSONDecoder().decode(FacebookAuthProviderInfo.self, from: data)
            case .apiKey: apiKeyAuthProviderInfo =
                try JSONDecoder().decode(ApiKeyAuthProviderInfo.self, from: data)
            case .emailPass: emailPasswordAuthProviderInfo =
                try JSONDecoder().decode(EmailPasswordAuthProviderInfo.self, from: data)
            case .anonymous: anonymousAuthProviderInfo =
                try JSONDecoder().decode(AnonymousAuthProviderInfo.self, from: data)
            }
        }
    }
}
