import Foundation
import ExtendedJson

/**
    An AuthProvider is responsible for providing the necessary information for a specific
    authentication request.
 */
public protocol AuthProvider {
    /// The authentication type of this provider.
    var type: String {get}
    /// The name of this provider.
    var name: String {get}
    /// The JSON payload containing authentication material.
    var payload: Document {get}
}

/// Provider enum representing current state of `AuthProvider`s.
public enum Provider {
    /// Google OAuth2 repr
    case google,
    /// Facebook OAuth2 repr
         facebook,
    /// Email and password authentication
         emailPassword,
    /// Anonymous Authentication
         anonymous

    var name: String {
        switch self {
        case .google:
            return "oauth2/google"
        case .facebook:
            return "oauth2/facebook"
        case .emailPassword:
            return "local/userpass"
        case .anonymous:
            return "anon/user"
        }
    }

    init?(name: String) {
        switch name {
        case Provider.google.name:
            self = .google
        case Provider.facebook.name:
            self = .facebook
        case Provider.emailPassword.name:
            self = .emailPassword
        case Provider.anonymous.name:
            self = .anonymous
        default:
            return nil
        }
    }
}
