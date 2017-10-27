import Foundation

/// Struct containing information about available providers
public struct AuthProviderInfo: Codable {
    private enum CodingKeys: String, CodingKey {
        case anonymousAuthProviderInfo = "anon/user"
        case googleProviderInfo = "oauth2/google"
        case facebookProviderInfo = "oauth2/facebook"
        case emailPasswordAuthProviderInfo = "local/userpass"
    }

    /// Info about the `AnonymousAuthProvider`
    public private(set) var anonymousAuthProviderInfo: AnonymousAuthProviderInfo?
    /// Info about the `GoogleAuthProvider`
    public private(set) var googleProviderInfo: GoogleAuthProviderInfo?
    /// Info about the `FacebookAuthProvider`
    public private(set) var facebookProviderInfo: FacebookAuthProviderInfo?
    /// Info about the `EmailPasswordAuthProvider`
    public private(set) var emailPasswordAuthProviderInfo: EmailPasswordAuthProviderInfo?
}
