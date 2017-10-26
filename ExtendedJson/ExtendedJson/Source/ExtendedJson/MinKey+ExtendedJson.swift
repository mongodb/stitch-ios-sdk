//
//  MinKey+ExtendedJson.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/3/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension MinKey: ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let json = xjson as? [String : Any],
            let min = json[ExtendedJsonKeys.minKey.rawValue] as? Int,
            min == 1,
            json.count == 1 else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: MinKey.self)
        }
        
        return MinKey()
    }
    
    public var toExtendedJson: Any {
        return [ExtendedJsonKeys.minKey.rawValue : 1]
    }
    
    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        if let other = other as? MinKey {
            return self == other
        }
        return false
    }
}
