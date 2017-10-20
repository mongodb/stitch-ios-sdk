import Foundation

/// FacebookAuthProviderInfo contains information needed to create a `GoogleAuthProvider`
public struct GoogleAuthProviderInfo {

    private struct Consts {
        static let clientIdKey =        "clientId"
        static let scopesKey =          "metadataFields"
    }

    /// ClientId of your Google application
    public private(set) var clientId: String
    /// Enabled scopes for your application
    public private(set) var scopes: [String]?

    /**
         - parameter dictionary: Dictionary containing the clientId and metadataFields for your app
     */
    init?(dictionary: [String: Any]) {

        guard let clientId = dictionary[Consts.clientIdKey] as? String
        else {
            return nil
        }

        if let scopes = dictionary[Consts.scopesKey] as? [String] {
            self.scopes = scopes
        }

        self.clientId = clientId
    }
}
