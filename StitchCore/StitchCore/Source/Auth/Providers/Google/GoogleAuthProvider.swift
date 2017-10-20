import Foundation

/// GoogleAuthProvider provides a way to authenticate via Google's OAuth 2.0 provider.
public struct GoogleAuthProvider: AuthProvider {
    /// The authentication type for google login.
    public var type: String {
        return "oauth2"
    }
    /// The name for google login
    public var name: String {
        return "google"
    }
    /// The JSON payload containing the authCode.
    public var payload: [String: Any] {
        return ["authCode": authCode]
    }

    private(set) var authCode: String

    // MARK: - Init
    /**
         - parameter authCode: Authorization code needed for login
     */
    public init(authCode: String) {
        self.authCode = authCode
    }
}
