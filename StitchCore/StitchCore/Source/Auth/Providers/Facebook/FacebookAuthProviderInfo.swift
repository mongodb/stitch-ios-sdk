import Foundation

/// FacebookAuthProviderInfo contains information needed to create a `FacebookAuthProvider`
public struct FacebookAuthProviderInfo: Codable {
    private enum CodingKeys: String, CodingKey {
        case appId = "clientId"
        case scopes = "metadataFields"
    }

    /// Id of your Facebook app
    public let appId: String
    /// Scopes enabled for this app
    public let scopes: [String]?
}
