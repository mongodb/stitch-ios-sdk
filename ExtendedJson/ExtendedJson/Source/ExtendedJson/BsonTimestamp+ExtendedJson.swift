//
//  BsonTimestamp+ExtendedJson.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/3/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension BsonTimestamp: ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let json = xjson as? [String : Any],
            let timestampJson = json[ExtendedJsonKeys.timestamp.rawValue] as? [String : UInt64],
            let timestamp = timestampJson["t"],
            let increment = timestampJson["i"] else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: BsonTimestamp.self)
        }
        
        return BsonTimestamp(time: TimeInterval(timestamp), increment: Int(increment))
    }
    
    public var toExtendedJson: Any {
        return [
            ExtendedJsonKeys.timestamp.rawValue : [
                "t": UInt64(self.time.timeIntervalSince1970),
                "i": UInt64(increment)
            ]
        ]
    }
    
    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        if let other = other as? BsonTimestamp {
            return self == other
        }
        return false
    }
}
