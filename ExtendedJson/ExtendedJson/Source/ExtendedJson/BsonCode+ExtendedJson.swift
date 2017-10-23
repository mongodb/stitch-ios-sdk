//
//  BsonCode+ExtendedJson.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/5/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension BsonCode: ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let json = xjson as? [String: Any],
            let code = json[ExtendedJsonKeys.code.rawValue] as? String else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: BsonCode.self)
        }

        if let scope = json["$scope"] {
            return BsonCode(code: code,
                            scope: try BsonDocument.fromExtendedJson(xjson: scope) as? BsonDocument)
        }

        return BsonCode(code: code, scope: nil)
    }

    public var toExtendedJson: Any {
        var code: [String: Any] = [
            ExtendedJsonKeys.code.rawValue: self.code
        ]

        if let scope = self.scope {
            code["$scope"] = scope.toExtendedJson
        }

        return code
    }

    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        if let other = other as? BsonCode {
            return self.code == other.code  && self.scope == other.scope
        }

        return false
    }
}
