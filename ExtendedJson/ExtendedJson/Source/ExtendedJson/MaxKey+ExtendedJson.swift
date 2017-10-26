//
//  MaxKey+ExtendedJson.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/4/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension MaxKey: ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let json = xjson as? [String : Any],
            let maxKey = json[ExtendedJsonKeys.maxKey.rawValue] as? Int,
            maxKey == 1,
            json.count == 1 else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: MaxKey.self)
        }
        
        return MaxKey()
    }
    
    public var toExtendedJson: Any {
        return [ExtendedJsonKeys.maxKey.rawValue : 1]
    }
    
    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        if let other = other as? MaxKey {
            return self == other
        }
        return false
    }
}
