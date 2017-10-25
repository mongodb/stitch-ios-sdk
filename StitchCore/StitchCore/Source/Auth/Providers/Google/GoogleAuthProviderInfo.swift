import Foundation

/// FacebookAuthProviderInfo contains information needed to create a `GoogleAuthProvider`
public struct GoogleAuthProviderInfo: Codable {
    private enum CodingKeys: String, CodingKey {
        case clientId
        case scopes = "metadataFields"
    }

    /// ClientId of your Google application
    public let clientId: String
    /// Enabled scopes for your application
    public let scopes: [String]?
}
