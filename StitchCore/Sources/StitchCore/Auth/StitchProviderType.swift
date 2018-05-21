import Foundation

/**
 * An enumeration of the types of authentication providers that can be used to authenticate with MongoDB Stitch.
 *
 * - important: The raw value here has no meaning to the Stitch server. Use the `name` field for the default name of
 *              of the authentication provider in MongoDB stitch.
 */
public enum StitchProviderType: String, Codable {
    /**
     * The anonymous authentication provider.
     */
    case anonymous

    /**
     * The custom authentication provider.
     */
    case custom

    /**
     * The Facebook OAuth2 authentication provider.
     */
    case facebook

    /**
     * The Google OAuth2 authentication provider.
     */
    case google

    /**
     * The server API key authentication provider.
     */
    case serverAPIKey

    /**
     * The user API key authentication provider.
     */
    case userAPIKey

    /**
     * The username/password authentication provider.
     */
    case userPassword

    /**
     * The default name of this provider in MongoDB Stitch.
     */
    public var name: String {
        switch self {
        case .anonymous:
            return "anon-user"
        case .custom:
            return "custom-token"
        case .facebook:
            return "oauth2-facebook"
        case .google:
            return "oauth2-google"
        case .serverAPIKey:
            return "api-key"
        case .userAPIKey:
            return "api-key"
        case .userPassword:
            return "local-userpass"
        }
    }
}
