//
//  FacebookAuthProvider.swift
//  MongoCore
//
//  Created by Ofer Meroz on 04/02/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

public struct FacebookAuthProvider: AuthProvider {
    
    public var type: String {
        return "oauth2"
    }
    
    public var name: String {
        return "facebook"
    }
    
    public var payload: [String : Any] {
        return ["accessToken" : accessToken]
    }
    
    private(set) var accessToken: String
    
    //MARK: - Init
    
    public init(accessToken: String) {
        self.accessToken = accessToken
    }
    
}
