//
//  AuthUser.swift
//  StitchCore
//
//  Created by Ofer Meroz on 02/02/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

public struct AuthUser {
    
    private static let idKey =              "userId"
    private static let identitiesKey =      "identities"
    private static let dataKey =            "data"
    
    public private(set) var id: String
    public private(set) var identities: [Identity]
    public private(set) var data: [String : Any]
    
    internal var json: [String : Any] {
        return [AuthUser.idKey : id,
                AuthUser.identitiesKey : identities.map{$0.json},
                AuthUser.dataKey : data]
    }
    
    
    //MARK: - Init
    
    internal init(dictionary: [String : Any]) throws {
        
        guard let id = dictionary[AuthUser.idKey] as? String,
            let identitiesArr = dictionary[AuthUser.identitiesKey] as? [[String : Any]],
            let data = dictionary[AuthUser.dataKey] as? [String : Any] else {
                throw StitchError.responseParsingFailed(reason: "failed creating AuthUser out of info: \(dictionary)")
        }
        
        var identities: [Identity] = []
        for identityDic in identitiesArr {
            if let identity = Identity(dictionary: identityDic) {
                identities.append(identity)
            }
        }
        
        self.id = id
        self.identities = identities
        self.data = data
    }
    
    //MARK: - Identity
    
    public struct Identity {
        
        private static let idKey =              "id"
        private static let providerKey =        "provider"
        
        private var id: String
        private var provider: String
        
        internal var json: [String : Any] {
            return [Identity.idKey : id,
                    Identity.providerKey : provider]
        }
        
        init?(dictionary: [String : Any]) {
            
            guard let id = dictionary[Identity.idKey] as? String,
                let provider = dictionary[Identity.providerKey] as? String else {
                    return nil
            }
            
            self.id = id
            self.provider = provider
        }
    }
}
