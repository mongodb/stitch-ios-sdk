//
//  NSNull+ExtendedJson.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/3/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension NSNull: ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let _ = xjson as? NSNull else {
            throw BsonError.parseValueFailure(value: xjson, attemptedType: NSNull.self)
        }

        return NSNull()
    }

    public var toExtendedJson: Any {
        return self
    }

    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        if let other = other as? NSNull {
            return self == other
        }
        return false
    }
}
