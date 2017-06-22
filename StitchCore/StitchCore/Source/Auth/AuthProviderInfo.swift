import Foundation

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
    
    //MARK: - Init
    /**
         - parameter dictionary: Dictionary containing all available provider
                                 names and their information (as a dict)
     */
    init(dictionary: [String : Any]) {
        
        for providerName in dictionary.keys {
            switch providerName {
            case Provider.google.name:
                if let googleProviderInfoDic = dictionary[providerName] as? [String : Any],
                    let googleProviderInfo = GoogleAuthProviderInfo(dictionary: googleProviderInfoDic) {
                    self.googleProviderInfo = googleProviderInfo
                }
            case Provider.facebook.name:
                if let facebookProviderInfoDic = dictionary[providerName] as? [String : Any],
                    let facebookProviderInfo = FacebookAuthProviderInfo(dictionary: facebookProviderInfoDic) {
                    self.facebookProviderInfo = facebookProviderInfo
                }
            case Provider.emailPassword.name:
                emailPasswordAuthProviderInfo = EmailPasswordAuthProviderInfo()
            case Provider.anonymous.name:
                anonymousAuthProviderInfo = AnonymousAuthProviderInfo()
            default:
                break
            }
        }
    }
    
    
}
