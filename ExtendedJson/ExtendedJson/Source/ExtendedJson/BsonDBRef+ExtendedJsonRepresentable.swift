//
//  DBRef+ExtendedJsonRepresentable.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/5/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension BsonDBRef: ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let json = xjson as? [String : Any],
            let ref = json[ExtendedJsonKeys.dbRef.rawValue] as? String,
            let idKey = json["$id"],
            let id = try ObjectId.fromExtendedJson(xjson: idKey) as? ObjectId else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: BsonDBRef.self)
        }
        
        return BsonDBRef(ref: ref,
                         id: id,
                         db: json["$db"] as? String,
                         otherFields: json.filter { $0.key.contains("$") })
    }
    
    public var toExtendedJson: Any {
        var dbRef: [String : Any] = [
            ExtendedJsonKeys.dbRef.rawValue: self.ref,
            "$id": self.id.toExtendedJson
        ]
        
        if let db = self.db {
            dbRef["$db"] = db
        }
        if self.otherFields.capacity > 0 {
            dbRef.merge(self.otherFields) { (_, current) in current }
        }
        
        return dbRef
    }
    
    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        if let other = other as? BsonDBRef {
            return other.id == self.id
        }
        
        return false
    }
}
