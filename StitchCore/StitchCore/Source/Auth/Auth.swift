//
//  Auth.swift
//  StitchCore
//
//  Created by Ofer Meroz on 02/02/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

public struct Auth {
    
    private static let accessTokenKey =         "accessToken"
    private static let userKey =                "user"
    private static let providerKey =            "provider"
    
    let accessToken: String
    let user: AuthUser
    public let provider: Provider
    
    var json: [String : Any] {
        return [Auth.accessTokenKey : accessToken,
                Auth.userKey : user.json,
                Auth.providerKey : provider.name]
    }
    
    
    //MARK: - Init
    
    private init(accessToken: String, user: AuthUser, provider: Provider) {
        self.accessToken = accessToken
        self.user = user
        self.provider = provider
    }
    
    internal init(dictionary: [String : Any]) throws {
        
        guard let accessToken = dictionary[Auth.accessTokenKey] as? String,
            let userDic = dictionary[Auth.userKey] as? [String : Any],
            let providerName = dictionary[Auth.providerKey] as? String,
            let provider = Provider(name: providerName) else {
                throw StitchError.responseParsingFailed(reason: "failed creating Auth out of info: \(dictionary)")
        }
        
        self = Auth(accessToken: accessToken, user: try AuthUser(dictionary: userDic), provider: provider)
    }
    
    internal func auth(with updatedAccessToken: String) -> Auth {
        return Auth(accessToken: updatedAccessToken, user: user, provider: provider)
    }
}
