//
//  BsonArray+ExtendedJson.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/4/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension BsonArray: ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let array = xjson as? [Any],
            let bsonArray = try? BsonArray(array: array) else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: BsonArray.self)
        }

        return bsonArray
    }

    public var toExtendedJson: Any {
        return map { $0.toExtendedJson }
    }

    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        if let other = other as? BsonArray, other.count == self.count {
            for i in 0..<other.count {
                let myExtendedJsonRepresentable = self[i]
                let otherExtendedJsonRepresentable = other[i]

                if !myExtendedJsonRepresentable.isEqual(toOther: otherExtendedJsonRepresentable) {
                    return false
                }
            }
        } else {
            return false
        }
        return true
    }
}
