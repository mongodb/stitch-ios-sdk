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

// MARK: - Helpers

internal enum ExtendedJsonKeys: String {
    case objectid = "$oid",
    numberInt = "$numberInt",
    numberLong = "$numberLong",
    numberDouble = "$numberDouble",
    numberDecimal = "$numberDecimal",
    date = "$date",
    binary = "$binary",
    code = "$code",
    timestamp = "$timestamp",
    regex = "$regularExpression",
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
