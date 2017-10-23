//
//  ExtendedJsonRepresentable.swift
//  ExtendedJson
//

import Foundation

public protocol ExtendedJsonRepresentable {
    static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable

    var toExtendedJson: Any { get }

    func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool
}

internal struct ExtendedJsonCodingKeys: CodingKey {
    var stringValue: String

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int?

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = ""
    }

    static let info = ExtendedJsonCodingKeys(stringValue: "__$info__")!
}

extension ExtendedJsonRepresentable {

    internal static func encode(to container: inout UnkeyedEncodingContainer,
                                encodingInfo: inout [String: String],
                                forKey key: String,
                                withValue value: ExtendedJsonRepresentable) throws {
        var infoKey: String?
        func setInfoKey(_ key: String) {
            if (infoKey == nil) {
                infoKey = key
            }
        }
        switch value {
        case is ObjectId: setInfoKey(ExtendedJsonKeys.objectid.rawValue); fallthrough
        case is BsonSymbol: setInfoKey(ExtendedJsonKeys.symbol.rawValue); fallthrough
        case is Decimal: setInfoKey(ExtendedJsonKeys.numberDecimal.rawValue); fallthrough
        case is Double: setInfoKey(ExtendedJsonKeys.numberDouble.rawValue); fallthrough
        case is Int32: setInfoKey(ExtendedJsonKeys.numberInt.rawValue); fallthrough
        case is Int64: setInfoKey(ExtendedJsonKeys.numberLong.rawValue); fallthrough
        case is Int: setInfoKey(ExtendedJsonKeys.numberLong.rawValue)
        try container.encode(value.toExtendedJson as! [String: String])
        case is BsonTimestamp: setInfoKey(ExtendedJsonKeys.timestamp.rawValue); fallthrough
        case is BsonDBPointer: setInfoKey(ExtendedJsonKeys.dbPointer.rawValue); fallthrough
        case is NSRegularExpression: setInfoKey(ExtendedJsonKeys.regex.rawValue); fallthrough
        case is UUID: setInfoKey(ExtendedJsonKeys.binary.rawValue); fallthrough
        case is Date: setInfoKey(ExtendedJsonKeys.date.rawValue); fallthrough
        case is BsonBinary: setInfoKey(ExtendedJsonKeys.binary.rawValue)
        try container.encode(value.toExtendedJson as! [String: [String: String]])
        case is BsonUndefined: setInfoKey(ExtendedJsonKeys.undefined.rawValue)
        try container.encode(value.toExtendedJson as! [String: Bool])
        case is MaxKey: setInfoKey(ExtendedJsonKeys.maxKey.rawValue); fallthrough
        case is MinKey: setInfoKey(ExtendedJsonKeys.minKey.rawValue)
        try container.encode(value.toExtendedJson as! [String: Int])
        case let val as BsonCode: setInfoKey(ExtendedJsonKeys.code.rawValue)
        try val.encode(to: container.superEncoder())
        case let val as BsonArray: setInfoKey("__$arr__")
        try val.encode(to: container.superEncoder())
        case let val as BsonDocument: setInfoKey("__$doc__")
        try val.encode(to: container.superEncoder())
        case is String: setInfoKey("__$str__")
        try container.encode(value.toExtendedJson as! String)
        case is Bool: setInfoKey("__$bool__")
        try container.encode(value.toExtendedJson as! Bool)
        case is NSNull: setInfoKey("__$nil__")
        try container.encodeNil()
        default: break
        }

        encodingInfo[key] = infoKey!
    }

    internal static func encode<T>(to container: inout KeyedEncodingContainer<T>,
                                   encodingInfo: inout [String: String],
                                   forKey key: T,
                                   withValue value: ExtendedJsonRepresentable) throws {
        var infoKey: String?
        func setInfoKey(_ key: String) {
            if (infoKey == nil) {
                infoKey = key
            }
        }
        switch value {
        case is ObjectId: setInfoKey(ExtendedJsonKeys.objectid.rawValue); fallthrough
        case is BsonSymbol: setInfoKey(ExtendedJsonKeys.symbol.rawValue); fallthrough
        case is Decimal: setInfoKey(ExtendedJsonKeys.numberDecimal.rawValue); fallthrough
        case is Double: setInfoKey(ExtendedJsonKeys.numberDouble.rawValue); fallthrough
        case is Int32: setInfoKey(ExtendedJsonKeys.numberInt.rawValue); fallthrough
        case is Int64: setInfoKey(ExtendedJsonKeys.numberLong.rawValue); fallthrough
        case is Int: setInfoKey(ExtendedJsonKeys.numberLong.rawValue)
            try container.encode(value.toExtendedJson as! [String: String],
                                 forKey: key)
        case is BsonTimestamp: setInfoKey(ExtendedJsonKeys.timestamp.rawValue); fallthrough
        case is BsonDBPointer: setInfoKey(ExtendedJsonKeys.dbPointer.rawValue); fallthrough
        case is NSRegularExpression: setInfoKey(ExtendedJsonKeys.regex.rawValue); fallthrough
        case is UUID: setInfoKey(ExtendedJsonKeys.binary.rawValue); fallthrough
        case is Date: setInfoKey(ExtendedJsonKeys.date.rawValue); fallthrough
        case is BsonBinary: setInfoKey(ExtendedJsonKeys.binary.rawValue)
            try container.encode(value.toExtendedJson as! [String: [String: String]],
                                 forKey: key)
        case is BsonUndefined: setInfoKey(ExtendedJsonKeys.undefined.rawValue)
            try container.encode(value.toExtendedJson as! [String: Bool],
                                 forKey: key)
        case is MaxKey: setInfoKey(ExtendedJsonKeys.maxKey.rawValue); fallthrough
        case is MinKey: setInfoKey(ExtendedJsonKeys.minKey.rawValue)
            try container.encode(value.toExtendedJson as! [String: Int],
                                 forKey: key)
        case let val as BsonCode: setInfoKey(ExtendedJsonKeys.code.rawValue)
            try val.encode(to: container.superEncoder(forKey: key))
        case let val as BsonArray: setInfoKey("__$arr__")
            try val.encode(to: container.superEncoder(forKey: key))
        case let val as BsonDocument: setInfoKey("__$doc__")
            try val.encode(to: container.superEncoder(forKey: key))
        case is String: setInfoKey("__$str__")
            try container.encode(value.toExtendedJson as! String, forKey: key)
        case is Bool: setInfoKey("__$bool__")
            try container.encode(value.toExtendedJson as! Bool, forKey: key)
        case is NSNull: setInfoKey("__$nil__")
            try container.encodeNil(forKey: key)
        default: break
        }

     encodingInfo[key.stringValue] = infoKey!
    }

    internal static func decode<T>(from container: KeyedDecodingContainer<T>,
                                   decodingInfo: [String: Codable],
                                   forKey key: T) throws -> ExtendedJsonRepresentable {
        return try decodingInfo.map { (_: String, v: Codable) throws -> [String: ExtendedJsonRepresentable] in
            switch v as! String {
//            case ExtendedJsonKeys.objectid.rawValue: return [k: try ObjectId.fromExtendedJson(xjson: json)]
//            case ExtendedJsonKeys.numberInt.rawValue: return [k: try Int32.fromExtendedJson(xjson: json)]
//            case ExtendedJsonKeys.numberLong.rawValue: return try Int64.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.numberDouble.rawValue: return try Double.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.numberDecimal.rawValue: return try Decimal.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.date.rawValue: return try Date.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.binary.rawValue: return try BsonBinary.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.timestamp.rawValue: return try BsonTimestamp.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.regex.rawValue: return try NSRegularExpression.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.dbRef.rawValue: return try BsonDBRef.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.minKey.rawValue: return try MinKey.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.maxKey.rawValue: return try MaxKey.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.undefined.rawValue: return try BsonUndefined.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.code.rawValue: return try BsonCode.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.symbol.rawValue: return try BsonSymbol.fromExtendedJson(xjson: json)
//            case ExtendedJsonKeys.dbPointer.rawValue: return try BsonDBPointer.fromExtendedJson(xjson: json)
            default: throw BsonError.parseValueFailure(value: "<unknown>", attemptedType: Any.self)
            }
        } as! ExtendedJsonRepresentable
    }

    public static func decodeXJson(value: Any?) throws -> ExtendedJsonRepresentable {
        switch (value) {
        case let json as [String: Any]:
            if json.count == 0 {
                return BsonDocument()
            }

            var iterator = json.makeIterator()
            while let next = iterator.next() {
                if let key = ExtendedJsonKeys(rawValue: next.key) {
                    switch (key) {
                    case .objectid: return try ObjectId.fromExtendedJson(xjson: json)
                    case .numberInt: return try Int32.fromExtendedJson(xjson: json)
                    case .numberLong: return try Int64.fromExtendedJson(xjson: json)
                    case .numberDouble: return try Double.fromExtendedJson(xjson: json)
                    case .numberDecimal: return try Decimal.fromExtendedJson(xjson: json)
                    case .date: return try Date.fromExtendedJson(xjson: json)
                    case .binary: return try BsonBinary.fromExtendedJson(xjson: json)
                    case .timestamp: return try BsonTimestamp.fromExtendedJson(xjson: json)
                    case .regex: return try NSRegularExpression.fromExtendedJson(xjson: json)
                    case .dbRef: return try BsonDBRef.fromExtendedJson(xjson: json)
                    case .minKey: return try MinKey.fromExtendedJson(xjson: json)
                    case .maxKey: return try MaxKey.fromExtendedJson(xjson: json)
                    case .undefined: return try BsonUndefined.fromExtendedJson(xjson: json)
                    case .code: return try BsonCode.fromExtendedJson(xjson: json)
                    case .symbol: return try BsonSymbol.fromExtendedJson(xjson: json)
                    case .dbPointer: return try BsonDBPointer.fromExtendedJson(xjson: json)
                    }
                }
            }

            return try BsonDocument(extendedJson: json)
        case is NSNull, nil:
            return try NSNull.fromExtendedJson(xjson: NSNull())
        case is [Any]:
            return try BsonArray.fromExtendedJson(xjson: value!)
        case is String:
            return try String.fromExtendedJson(xjson: value!)
        case is Bool:
            return try Bool.fromExtendedJson(xjson: value!)
        default:
            throw BsonError.parseValueFailure(value: value, attemptedType: BsonDocument.self)
        }
    }
}

// MARK: - Helpers
internal enum ExtendedJsonKeys: String {
    case objectid = "$oid",
    symbol = "$symbol",
    numberInt = "$numberInt",
    numberLong = "$numberLong",
    numberDouble = "$numberDouble",
    numberDecimal = "$numberDecimal",
    date = "$date",
    binary = "$binary",
    code = "$code",
    timestamp = "$timestamp",
    regex = "$regularExpression",
    dbPointer = "$dbPointer",
    dbRef = "$ref",
    minKey = "$minKey",
    maxKey = "$maxKey",
    undefined = "$undefined"
}

// MARK: ISO8601

internal extension DateFormatter {

    static let iso8601DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
}
