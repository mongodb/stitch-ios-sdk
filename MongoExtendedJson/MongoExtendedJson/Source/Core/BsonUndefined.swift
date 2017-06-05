//
//  BsonUndefined.swift
//  MongoExtendedJson
//
//  Created by Ofer Meroz on 26/02/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public struct BsonUndefined {
    
    public init(){}
}

// MARK: - Equatable

extension BsonUndefined: Equatable {
    public static func ==(lhs: BsonUndefined, rhs: BsonUndefined) -> Bool {
        return true
    }
}
