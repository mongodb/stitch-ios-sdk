//
//  BsonTimestamp.swift
//  ExtendedJson
//

import Foundation

public struct BsonTimestamp {

    public private(set) var time: Date
    public private(set) var increment: Int

    public init(time: Date, increment: Int) {
        self.time = time
        self.increment = increment
    }

    public init(time: TimeInterval, increment: Int) {
        self.time = Date(timeIntervalSince1970: time)
        self.increment = increment
    }
}

// MARK: - Equatable

extension BsonTimestamp: Equatable {
    public static func ==(lhs: BsonTimestamp, rhs: BsonTimestamp) -> Bool {
        return UInt64(lhs.time.timeIntervalSince1970) == UInt64(rhs.time.timeIntervalSince1970)
    }
}
