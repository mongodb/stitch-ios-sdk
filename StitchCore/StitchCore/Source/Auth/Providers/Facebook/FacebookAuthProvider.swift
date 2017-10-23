import Foundation
import ExtendedJson

/// FacebookAuthProvider provides a way to authenticate via Facebook's OAuth 2.0 provider.
public struct FacebookAuthProvider: AuthProvider {
    /// The authentication type for facebook login.
    public var type: String {
        return "oauth2"
    }

    /// The name for facebook login
    public var name: String {
        return "facebook"
    }

    /// The JSON payload containing the accessToken.
    public var payload: BsonDocument {
        return ["accessToken": accessToken]
    }

    private(set) var accessToken: String

    // MARK: - Init
    /**
         - parameter accessToken: Access token for log in
     */
    public init(accessToken: String) {
        self.accessToken = accessToken
    }
}
