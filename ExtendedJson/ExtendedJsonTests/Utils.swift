//
//  Utils.swift
//  ExtendedJsonTests
//
//  Created by Jason Flax on 10/22/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import ExtendedJson

let _id = "_id"
let symbol = "Symbol"
let string = "String"
let int32 = "Int32"
let int64 = "Int64"
let double = "Double"
let specialFloat = "SpecialFloat"
let decimal = "Decimal"
let binary = "Binary"
let binaryUserDefined = "BinaryUserDefined"
let code = "Code"
let codeWithScope = "CodeWithScope"
let subDocument = "SubDocument"
let array = "Array"
let timestamp = "Timestamp"
let regularExpression = "RegularExpression"
let datetimeEpoch = "DatetimeEpoch"
let datetimePositive = "DatetimePositive"
let datetimeNegative = "DatetimeNegative"
let `true` = "True"
let `false` = "False"
let dbPointer = "DBPointer"
let dbRef = "DBRef"
let dbRefNoDB = "DBRefNoDB"
let minKey = "MinKey"
let maxKey = "MaxKey"
let null = "Null"
let undefined = "Undefined"

let keys = [_id, symbol, string, int32, int64, double, specialFloat, decimal,
            binary, binaryUserDefined, code, codeWithScope, subDocument,
            array, timestamp, regularExpression, datetimeEpoch, datetimePositive,
            datetimeNegative, `true`, `false`, dbPointer, dbRef, dbRefNoDB,
            minKey, maxKey, null, undefined]

let goodDoc: BsonDocument = [
    _id: try! ObjectId(hexString: "57e193d7a9cc81b4027498b5"),
    symbol: BsonSymbol("symbol"),
    string: "string",
    int32: Int32(42),
    int64: Int64(42),
    double: 42.42,
    specialFloat: Double.nan,
    decimal: Decimal(1234),
    binary: UUID(uuidString: "a34c38f7-c3ab-edc8-a378-14a992ab8db6")!,
    binaryUserDefined: BsonBinary(type: BsonBinarySubType(rawValue: 0x80)!,
                                  data: [UInt8](arrayLiteral: 1, 2, 3, 4, 5)),
    code: BsonCode(code: "function() {}"),
    codeWithScope: BsonCode(code: "function() {}", scope: BsonDocument()),
    subDocument: try! BsonDocument(key: "foo", value: "bar"),
    array: [1, 2, 3, 4, 5] as BsonArray,
    timestamp: BsonTimestamp(time: 42, increment: 1),
    regularExpression: try! NSRegularExpression(pattern: "foo*", options: NSRegularExpression.Options("xi")),
    datetimeEpoch: Date(timeIntervalSince1970: TimeInterval(0)),
    datetimePositive: Date(timeIntervalSince1970: TimeInterval(Int64.max)),
    datetimeNegative: Date(timeIntervalSince1970: TimeInterval(Int64.min)),
    `true`: true,
    `false`: false,
    dbPointer: BsonDBPointer(ref: "db.collection",
                             id: try! ObjectId(hexString: "57e193d7a9cc81b4027498b1")),
    dbRef: BsonDBRef(ref: "collection",
                     id: try! ObjectId(hexString: "57fd71e96e32ab4225b723fb"),
                     db: "database",
                     otherFields: [String: ExtendedJsonRepresentable]()),
    dbRefNoDB: BsonDBRef(ref: "collection",
                         id: try! ObjectId(hexString: "57fd71e96e32ab4225b723fb"),
                         db: nil,
                         otherFields: [String: ExtendedJsonRepresentable]()),
    minKey: MinKey(),
    maxKey: MaxKey(),
    null: NSNull(),
    undefined: BsonUndefined()
]

let badDoc: BsonDocument = [
    _id: ObjectId.NewObjectId(),
    symbol: BsonSymbol("lobmys"),
    string: "gnirts",
    int32: Int32(24),
    int64: Int64(24),
    double: 24.24,
    specialFloat: Double.infinity,
    decimal: Decimal(4321),
    binary: UUID(uuidString: "c8edabc3-f739-4ca3-b68d-ab92a91478a3")!,
    binaryUserDefined: BsonBinary(type: BsonBinarySubType(rawValue: 0x80)!,
                                  data: [UInt8](arrayLiteral: 6, 7, 8, 9, 10)),
    code: BsonCode(code: "function() { console.log('foo') }"),
    codeWithScope: BsonCode(code: "function() { console.log('foo') }", scope: BsonDocument()),
    subDocument: try! BsonDocument(key: "baz", value: "qux"),
    array: [6, 7, 8, 9, 10] as BsonArray,
    timestamp: BsonTimestamp(time: 24, increment: 2),
    regularExpression: try! NSRegularExpression(pattern: "bar*", options: NSRegularExpression.Options("xi")),
    datetimeEpoch: Date.timeIntervalSinceReferenceDate,
    datetimePositive: Date(timeIntervalSince1970: TimeInterval(Int64.min)),
    datetimeNegative: Date(timeIntervalSince1970: TimeInterval(Int64.max)),
    `true`: false,
    `false`: true,
    dbPointer: BsonDBPointer(ref: "db.collection",
                             id: ObjectId.NewObjectId()),
    dbRef: BsonDBRef(ref: "collection",
                     id: ObjectId.NewObjectId(),
                     db: "database",
                     otherFields: [:]),
    dbRefNoDB: BsonDBRef(ref: "collection",
                         id: ObjectId.NewObjectId(),
                         db: nil,
                         otherFields: [:]),
    minKey: MaxKey(),
    maxKey: MinKey(),
    null: "nil",
    undefined: "undefined"
]

let specDocDict: [String: Any?] = [
    _id: [
        "$oid": "57e193d7a9cc81b4027498b5"
    ],
    symbol: [
        "$symbol": "symbol"
    ],
    string: "string",
    int32: [
        "$numberInt": "42"
    ],
    int64: [
        "$numberLong": "42"
    ],
    double: [
        "$numberDouble": "42.42"
    ],
    specialFloat: [
        "$numberDouble": "NaN"
    ],
    decimal: [
        "$numberDecimal": "1234"
    ],
    binary: [
        "$binary": [
            "base64": "o0w498Or7cijeBSpkquNtg==",
            "subType": "03"
        ]
    ],
    binaryUserDefined: [
        "$binary": [
            "base64": "AQIDBAU=",
            "subType": "80"
        ]
    ],
    code: [
        "$code": "function() {}"
    ],
    codeWithScope: [
        "$code": "function() {}",
        "$scope": []
    ],
    subDocument: [
        "foo": "bar"
    ],
    array: [
        ["$numberInt": "1"],
        ["$numberInt": "2"],
        ["$numberInt": "3"],
        ["$numberInt": "4"],
        ["$numberInt": "5"]
    ],
    timestamp: [
        "$timestamp": [ "t": 42, "i": 1 ]
    ],
    regularExpression: [
        "$regularExpression": [
            "pattern": "foo*",
            "options": "ix"
        ]
    ],
    datetimeEpoch: [
        "$date": [
            "$numberLong": "0"
        ]
    ],
    datetimePositive: [
        "$date": [
            "$numberLong": "9223372036854775807"
        ]
    ],
    datetimeNegative: [
        "$date": [
            "$numberLong": "-9223372036854775808"
        ]
    ],
    `true`: true,
    `false`: false,
    dbPointer: [
        "$dbPointer": [
            "$ref": "db.collection",
            "$id": [
                "$oid": "57e193d7a9cc81b4027498b1"
            ]
        ]
    ],
    dbRef: [
        "$ref": "collection",
        "$id": [
            "$oid": "57fd71e96e32ab4225b723fb"
        ],
        "$db": "database"
    ],
    dbRefNoDB: [
        "$ref": "collection",
        "$id": [
            "$oid": "57fd71e96e32ab4225b723fb"
        ]
    ],
    minKey: [
        "$minKey": 1
    ],
    maxKey: [
        "$maxKey": 1
    ],
    null: nil,
    undefined: [
        "$undefined": true
    ]
]
