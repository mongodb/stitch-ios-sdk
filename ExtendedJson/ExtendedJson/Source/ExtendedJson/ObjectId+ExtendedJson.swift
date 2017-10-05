//
//  ObjectId+ExtendedJson.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/3/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension ObjectId: ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let json = xjson as? [String : Any],
            let value = json[ExtendedJsonKeys.objectid.rawValue] as? String else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: ObjectId.self)
        }
        
        return try ObjectId(hexString: value)
    }
    
    public var toExtendedJson: Any {
        return [ExtendedJsonKeys.objectid.rawValue : hexString]
    }
    
    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        if let other = other as? ObjectId {
            return self == other
        }
        return false
    }
}
