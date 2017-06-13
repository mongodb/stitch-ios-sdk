//
//  PushProviderInfo.swift
//  MongoCore
//
//  Created by Jay Flax on 6/5/17.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation
import ExtendedJson

public enum PushProviderInfoFields: String {
    case FieldType = "type"
    case Config = "config"
}

public protocol PushProviderInfo {
    var providerName: PushProviderName { get }
    var serviceName: String { get }
}

public class PushProviderInfoHelper {
    static func fromPreferences() throws -> [PushProviderInfo] {
        let userDefaults: UserDefaults = UserDefaults(suiteName: Consts.UserDefaultsName)!
        var configs = Document()
        do {
            configs = try Document(extendedJson: userDefaults.value(forKey: PrefConfigs) as! [String : Any])
        } catch _ {
            configs = Document()
        }
        
        return try configs.map { configEntry in
            let info: Document = configEntry.value as! Document
            
            let providerNameOpt = PushProviderName.fromTypeName(typename: info[PushProviderInfoFields.FieldType.rawValue] as! String)
            
            if let providerName = providerNameOpt {
                let config = info[PushProviderInfoFields.Config.rawValue] as! Document
                
                switch (providerName) {
                case .GCM: return StitchGCMPushProviderInfo.fromConfig(serviceName: configEntry.key, config: config)
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
