import Foundation
import ExtendedJson

internal enum PushProviderInfoFields: String {
    case FieldType = "type"
    case Config = "config"
}

/// Protocol for the information for any given push provider
public protocol PushProviderInfo {
    /// Name of this provider
    var providerName: PushProviderName { get }
    /// Name of the associated service
    var serviceName: String { get }
    /**
     Convert this into dictionary to be read/wrote to storage
     
     - Returns: A dictionary containing providerName, senderId, and config fields
     */
    func toDict() -> [String : Any]
}

/// Helper class to construct PushProviderInfo from persistent storage
public class PushProviderInfoHelper {
    /**
        Read saved provider information from the UserDefaults
 
        - Throws: `StitchError` if non-existant providers have been saved
 
        - Returns: A list of `PushProviderInfo`
    */
    public class func fromPreferences() throws -> [PushProviderInfo] {
        let userDefaults: UserDefaults = UserDefaults(suiteName: Consts.UserDefaultsName)!

        let configs = userDefaults.value(forKey: PrefConfigs) as? [String: Any] ?? [String : Any]()
        
        print(configs)
        return try configs.map { configEntry in
            let info: [String: Any]  = configEntry.value as! [String : Any]
            
            let providerNameOpt = PushProviderName.fromTypeName(typename: info[PushProviderInfoFields.FieldType.rawValue] as! String)
            
            if let providerName = providerNameOpt {
                let config = info[PushProviderInfoFields.Config.rawValue] as! [String: Any]
                
                switch (providerName) {
                case .GCM: return StitchGCMPushProviderInfo.fromConfig(serviceName: configEntry.key, senderId: config[StitchGCMProviderInfoFields.SenderID.rawValue] as! String)
                }
            } else {
                throw StitchError.illegalAction(message: "Provider does not exist")
            }
        }
    }
}

extension PushProviderInfo {
    /**
     Convert PushProviderInfo to a document.
     -returns: The provider info as a serializable document.
     */
    public func toDocument() -> Document {
        var doc = Document()
        doc[PushProviderInfoFields.FieldType.rawValue] = providerName as? ExtendedJsonRepresentable
        doc[PushProviderInfoFields.Config.rawValue] = Document()
        return doc
    }
}
