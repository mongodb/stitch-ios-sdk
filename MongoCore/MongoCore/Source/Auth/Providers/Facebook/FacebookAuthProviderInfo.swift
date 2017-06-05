//
//  FacebookAuthProviderInfo.swift
//  MongoCore
//
//  Created by Ofer Meroz on 04/02/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

public struct FacebookAuthProviderInfo {    
    
    private struct Consts {
        static let clientIdKey =        "clientId"
        static let scopesKey =          "metadataFields"
    }
    
    public private(set) var appId: String
    public private(set) var scopes: [String]
    
    
    init?(dictionary: [String : Any]) {
        
        guard let appId = dictionary[Consts.clientIdKey] as? String,
            let scopes = dictionary[Consts.scopesKey] as? [String]
            else {
                return nil
        }
        
        self.appId = appId
        self.scopes = scopes
    }
}
