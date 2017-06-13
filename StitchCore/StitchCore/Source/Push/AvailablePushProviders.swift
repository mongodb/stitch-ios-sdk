//
//  AvailablePushProviders.swift
//  StitchCore
//
//  Created by Jay Flax on 6/12/17.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation
import ExtendedJson

public class AvailablePushProviders {
    public var gcm: StitchGCMPushProviderInfo?
    
    init(gcm: StitchGCMPushProviderInfo?) {
        self.gcm = gcm
    }
    
    private class Builder {
        private var _gcm: StitchGCMPushProviderInfo?
        
        init() {}
        
        fileprivate func build() -> AvailablePushProviders {
            return AvailablePushProviders(gcm: _gcm)
        }
        
        fileprivate func withGCM(gcmInfo: StitchGCMPushProviderInfo) { _gcm = gcmInfo }
    }
    
    /**
     * @param json The data returned from Stitch about the providers.
     * @return A manifest of available push providers.
     */
    static func fromQuery(doc: Document) -> AvailablePushProviders {
        let builder = Builder()
        
        doc.forEach { configEntry in
            let info = configEntry.value as! Document
            
            let providerName = PushProviderName.fromTypeName(typename: info[PushProviderInfoFields.FieldType.rawValue] as! String)
            let config = info[PushProviderInfoFields.Config.rawValue] as! Document
            
            if let providerName = providerName {
                switch (providerName) {
                case .GCM:
                    let provider = StitchGCMPushProviderInfo.fromConfig(serviceName: configEntry.key, senderId: config[StitchGCMProviderInfoFields.SenderID.rawValue] as! String)
                    builder.withGCM(gcmInfo: provider)
                    break
                }
            }
        }

        return builder.build()
    }
}
