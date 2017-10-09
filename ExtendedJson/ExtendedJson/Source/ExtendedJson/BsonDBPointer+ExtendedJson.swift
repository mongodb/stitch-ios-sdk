//
//  BsonDBPointer+ExtendedJson.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/6/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension BsonDBPointer : ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let json = xjson as? [String : Any],
            let dbPointer = json[ExtendedJsonKeys.dbPointer.rawValue] as? [String : Any],
            let ref = dbPointer[ExtendedJsonKeys.dbRef.rawValue] as? String,
            let oid = dbPointer["$id"],
            let id = try ObjectId.fromExtendedJson(xjson: oid) as? ObjectId else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: BsonDBPointer.self)
        }
        
        return BsonDBPointer(ref: ref, id: id)
    }
    
    public var toExtendedJson: Any {
        return [
            ExtendedJsonKeys.dbPointer.rawValue : [
                ExtendedJsonKeys.dbRef : self.ref,
                ExtendedJsonKeys.objectid : self.id.toExtendedJson
            ]
        ]
    }
    
    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        return other is BsonDBPointer &&
            (other as! BsonDBPointer).id == self.id &&
            (other as! BsonDBPointer).ref == self.ref
    }
}
