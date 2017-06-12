//
//  AnonymousAuthProvider.swift
//  StitchCore
//
//  Created by Ofer Meroz on 09/02/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

public struct AnonymousAuthProvider: AuthProvider {
    
    public var type: String {
        return "anon"
    }
    
    public var name: String {
        return "user"
    }
    
    public var payload: [String : Any] {
        return [:]
    }
}
