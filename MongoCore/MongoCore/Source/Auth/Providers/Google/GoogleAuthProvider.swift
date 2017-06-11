//
//  GoogleAuthProvider.swift
//  MongoCore
//
//  Created by Ofer Meroz on 02/02/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

public struct GoogleAuthProvider: AuthProvider {
    
    public var type: String {
        return "oauth2"
    }
    
    public var name: String {
        return "google"
    }
    
    public var payload: [String : Any] {
        return ["authCode" : authCode]
    }
    
    private(set) var authCode: String
    
    //MARK: - Init
    
    public init(authCode: String) {
        self.authCode = authCode
    }
    
}
