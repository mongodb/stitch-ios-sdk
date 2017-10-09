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
            let timestampJson = json[ExtendedJsonKeys.timestamp.rawValue] as? [String : Int],
            let timestamp = timestampJson["t"],
            let increment = timestampJson["i"],
            timestampJson.count == 2 else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: BsonTimestamp.self)
        }
        
        return BsonTimestamp(time: TimeInterval(timestamp), increment: Int(increment))
    }
    
    public var toExtendedJson: Any {
        return [
            ExtendedJsonKeys.timestamp.rawValue : [
                "t": self.time.timeIntervalSince1970,
                "i": increment
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
