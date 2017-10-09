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

extension ExtendedJsonRepresentable {
    public static func decodeXJson(value: Any?) throws -> ExtendedJsonRepresentable {
        switch (value) {
        case let json as [String : Any]:
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
