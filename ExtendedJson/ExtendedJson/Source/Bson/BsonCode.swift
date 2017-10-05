//
//  BsonCode.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/5/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public struct BsonCode {
    let code: String
    let scope: Document?
    
    public init(code: String, scope: Document?) {
        self.code = code
        self.scope = scope
    }
}
