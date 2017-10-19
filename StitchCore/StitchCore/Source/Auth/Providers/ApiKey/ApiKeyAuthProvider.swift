//
//  ApiKeyAuthProvider.swift
//  StitchCore
//
//  Created by Jason Flax on 10/18/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public struct ApiKeyAuthProvider: AuthProvider {
    private let key: String

    public var type: String = "api"
    public var name: String = "key"
    
    public var payload: [String : Any] {
        return ["key" : key]
    }
    
    public init(key: String) {
        self.key = key
    }
}
