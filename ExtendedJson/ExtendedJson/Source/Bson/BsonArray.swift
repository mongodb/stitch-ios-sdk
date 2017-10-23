//
//  BsonArray.swift
//  ExtendedJson
//

import Foundation

public struct BsonArray: Codable {
    private struct CodingKeys: CodingKey {
        var stringValue: String

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int?

        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = String(intValue)
        }

        static let info = CodingKeys(stringValue: "__$info__")!
        static let array = CodingKeys(stringValue: "__$arr__")!
    }

    fileprivate var underlyingArray: [ExtendedJsonRepresentable] = []

    public init() {}

    public init(array: [ExtendedJsonRepresentable]) {
        underlyingArray = array
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ExtendedJsonCodingKeys.self)
        let infoContainer = try container.superDecoder(forKey: ExtendedJsonCodingKeys.info)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
//        var infoEncoder = container.superEncoder(forKey: ExtendedJsonCodingKeys.info)
        var infoContainer = [String: String]()
        for index in 0..<self.count {
            try BsonArray.encode(to: &container,
                                 encodingInfo: &infoContainer,
                                 forKey: String(index),
                                 withValue: self[index])
        }
//        var subContainer = infoEncoder.container(keyedBy: ExtendedJsonCodingKeys.self)
//        try subContainer.encode(infoContainer, forKey: ExtendedJsonCodingKeys.info)
    }
    public init(array: [Any]) throws {
        underlyingArray = try array.map { (any) -> ExtendedJsonRepresentable in
            return try BsonDocument.decodeXJson(value: any)
        }
    }

    public mutating func remove(object: ExtendedJsonRepresentable) -> Bool {
        for i in 0..<underlyingArray.count {
            let currentObject = underlyingArray[i]
            if currentObject.isEqual(toOther: object) {
                underlyingArray.remove(at: i)
                return true
            }
        }
        return false
    }
}

// MARK: - Collection

extension BsonArray: Collection {

    public typealias Index = Int

    public var startIndex: Index {
        return underlyingArray.startIndex
    }

    public var endIndex: Index {
        return underlyingArray.endIndex
    }

    public func makeIterator() -> IndexingIterator<[ExtendedJsonRepresentable]> {
        return underlyingArray.makeIterator()
    }

    public subscript(index: Int) -> ExtendedJsonRepresentable {
        get {
            return underlyingArray[index]
        }
        set(newElement) {
            underlyingArray.insert(newElement, at: index)
        }
    }

    public func index(after i: Index) -> Index {
        return underlyingArray.index(after: i)
    }

    // MARK: Mutating

    public mutating func append(_ newElement: ExtendedJsonRepresentable) {
        underlyingArray.append(newElement)
    }

    public mutating func remove(at index: Int) {
        underlyingArray.remove(at: index)
    }

}

extension BsonArray: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: ExtendedJsonRepresentable...) {
        self.init()
        underlyingArray = elements
    }
}
