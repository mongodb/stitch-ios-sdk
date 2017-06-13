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
    private let _gcm: StitchGCMPushProviderInfo?
    
    init(gcm: StitchGCMPushProviderInfo?) {
        self._gcm = gcm
    }
    
    private class Builder {
        private var _gcm: StitchGCMPushProviderInfo?
        
        init() {}
        
        fileprivate func build() -> AvailablePushProviders {
            return AvailablePushProviders(gcm: _gcm)
        }
        
        fileprivate func withGCM(gcmInfo: StitchGCMPushProviderInfo) { _gcm = gcmInfo }
    }
    
    var hasGCM: Bool {
        get {
            return _gcm != nil
        }
    }
    
    /**
     * @param json The data returned from Stitch about the providers.
     * @return A manifest of available push providers.
     */
    static func fromQuery(json: ExtendedJsonRepresentable) -> AvailablePushProviders {
        var doc: Document?
        do {
            doc = try Document(extendedJson: json as! [String : Any])
        } catch _ {
            return AvailablePushProviders(gcm: nil)
        }
        
        let builder = Builder()
        
        doc?.forEach { configEntry in
            let info = configEntry.value as! Document
            
            let providerName = PushProviderName.fromTypeName(typename: info[PushProviderInfoFields.FieldType.rawValue] as! String)
            let config = info[PushProviderInfoFields.Config.rawValue] as! Document
            
            if let providerName = providerName {
                switch (providerName) {
                case .GCM:
                    let provider = StitchGCMPushProviderInfo.fromConfig(serviceName: configEntry.key, config: config)
                    builder.withGCM(gcmInfo: provider)
                    break
                }
            }
        }

        return builder.build()
    }
}
