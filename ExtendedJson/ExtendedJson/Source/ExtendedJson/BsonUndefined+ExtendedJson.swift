//
//  BsonUndefined+ExtendedJson.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/4/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension BsonUndefined: ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let json = xjson as? [String : Any],
            let undefined = json[ExtendedJsonKeys.undefined.rawValue] as? Bool,
            undefined else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: BsonUndefined.self)
        }
        
        return BsonUndefined()
    }
    
    public var toExtendedJson: Any {
        return [ExtendedJsonKeys.undefined.rawValue : true]
    }
    
    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        if let other = other as? BsonUndefined {
            return self == other
        }
        return false
    }
}
