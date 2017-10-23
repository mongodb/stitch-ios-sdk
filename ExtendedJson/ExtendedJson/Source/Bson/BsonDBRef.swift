//
//  DBRef.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/2/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public struct BsonDBRef: Codable {
    struct BsonDBRefKey: CodingKey, Hashable {
        static func ==(lhs: BsonDBRef.BsonDBRefKey, rhs: BsonDBRef.BsonDBRefKey) -> Bool {
            return lhs.stringValue == rhs.stringValue
        }

        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int?
        init?(intValue: Int) { return nil }

        var hashValue: Int {
            return stringValue.hashValue
        }

        static let ref = BsonDBRefKey(stringValue: "$ref")!
        static let id = BsonDBRefKey(stringValue: "$id")!
        static let db = BsonDBRefKey(stringValue: "$db")!
    }

    let ref: String
    let id: ObjectId
    let db: String?
    let otherFields: [String: ExtendedJsonRepresentable]

    public init (ref: String,
                 id: ObjectId,
                 db: String?,
                 otherFields: [String: ExtendedJsonRepresentable]) {
        self.ref = ref
        self.id = id
        self.db = db
        self.otherFields = otherFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: BsonDBRefKey.self)

        self.ref = try container.decode(String.self, forKey: BsonDBRefKey.ref)
        self.id = try container.decode(ObjectId.self, forKey: BsonDBRefKey.id)
        self.db = try container.decode(String.self, forKey: BsonDBRefKey.db)

        let infoEncoder = try container.superDecoder(forKey: BsonDBRefKey(stringValue: "__$info__")!)
        let infoContainer = try infoEncoder.container(keyedBy: ExtendedJsonCodingKeys.self)
            .decode([String: Codable].self, forKey: ExtendedJsonCodingKeys.info)

        let otherFieldKeys = Set<BsonDBRefKey>(
            arrayLiteral: BsonDBRefKey.ref, BsonDBRefKey.id, BsonDBRefKey.db
        ).symmetricDifference(container.allKeys)

        self.otherFields = try otherFieldKeys.reduce(into: [String: ExtendedJsonRepresentable]()) { (result: inout [String: ExtendedJsonRepresentable], key: BsonDBRefKey) throws in
            result[key.stringValue] = try BsonDBRef.decode(from: container,
                                                           decodingInfo: infoContainer,
                                                           forKey: key)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: BsonDBRefKey.self)
        let infoEncoder = container.superEncoder(forKey: BsonDBRefKey(stringValue: "__$info__")!)
        var infoContainer = [String: String]()
        try container.encode(ref, forKey: BsonDBRefKey.ref)
        try container.encode(id, forKey: BsonDBRefKey.id)
        try container.encode(db, forKey: BsonDBRefKey.db)

        try otherFields.forEach {
            let (k, v) = $0
            try BsonDBRef.encode(to: &container,
                                 encodingInfo: &infoContainer,
                                 forKey: BsonDBRefKey(stringValue: k)!,
                                 withValue: v)
        }

        var subContainer = infoEncoder.container(keyedBy: ExtendedJsonCodingKeys.self)
        try subContainer.encode(infoContainer, forKey: ExtendedJsonCodingKeys.info)
    }
}
