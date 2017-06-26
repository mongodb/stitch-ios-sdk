import Foundation

/// FacebookAuthProviderInfo contains information needed to create a `FacebookAuthProvider`
public struct FacebookAuthProviderInfo {    
    
    private struct Consts {
        static let clientIdKey =        "clientId"
        static let scopesKey =          "metadataFields"
    }
    
    /// Id of your Facebook app
    public private(set) var appId: String
    /// Scopes enabled for this app
    public private(set) var scopes: [String]?
    
    /**
         - parameter dictionary: Dictionary containing the clientId and metadataFields
     */
    init?(dictionary: [String : Any]) {
        
        guard let appId = dictionary[Consts.clientIdKey] as? String
            else {
                return nil
        }
        
        if let scopes = dictionary[Consts.scopesKey] as? [String] {
            self.scopes = scopes
        }

        self.appId = appId
    }
}
