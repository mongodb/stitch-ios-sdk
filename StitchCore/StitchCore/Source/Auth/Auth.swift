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
    private static let deviceId =               "deviceId"
    
    let accessToken: String
    let user: AuthUser
    let deviceId: String
    public let provider: Provider
    
    var json: [String : Any] {
        return [Auth.accessTokenKey : accessToken,
                Auth.userKey : user.json,
                Auth.providerKey : provider.name,
                Auth.deviceId : deviceId]
    }
    
    
    //MARK: - Init
    
    private init(accessToken: String, user: AuthUser, provider: Provider, deviceId: String) {
        self.accessToken = accessToken
        self.user = user
        self.provider = provider
        self.deviceId = deviceId
    }
    
    internal init(dictionary: [String : Any]) throws {
        
        guard let accessToken = dictionary[Auth.accessTokenKey] as? String,
            let userDic = dictionary[Auth.userKey] as? [String : Any],
            let providerName = dictionary[Auth.providerKey] as? String,
            let provider = Provider(name: providerName),
            let deviceId = dictionary[Auth.deviceId] as? String else {
                throw StitchError.responseParsingFailed(reason: "failed creating Auth out of info: \(dictionary)")
        }
        
        self = Auth(accessToken: accessToken, user: try AuthUser(dictionary: userDic), provider: provider, deviceId: deviceId)
    }
    
    internal func auth(with updatedAccessToken: String) -> Auth {
        return Auth(accessToken: updatedAccessToken, user: user, provider: provider, deviceId: deviceId)
    }
}
