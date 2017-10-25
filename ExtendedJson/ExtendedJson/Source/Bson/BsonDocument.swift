//
//  Document.swift
//  ExtendedJson
//

import Foundation

public struct BsonDocument: BsonCollection, Codable, Collection {
    public typealias Element = (key: String, value: ExtendedJsonRepresentable)

    fileprivate var storage: [String: ExtendedJsonRepresentable] = [:]
    internal var orderedKeys: [String] = []

    private let writeQueue = DispatchQueue.global(qos: .utility)

    public init() {
    }

    public init(key: String, value: ExtendedJsonRepresentable) {
        self[key] = value
        orderedKeys.append(key)
    }

    public init(dictionary: [String: ExtendedJsonRepresentable?]) {
        for (key, value) in dictionary {
            self[key] = value ?? nil
            orderedKeys.append(key)
        }
    }

    public init(extendedJson json: [String: Any?]) throws {
        for (key, value) in json {
            self[key] = try BsonDocument.decodeXJson(value: value)
            orderedKeys.append(key)
        }
    }

    public func index(after i: Dictionary<BsonDocument.Key, BsonDocument.Value>.Index) -> Dictionary<BsonDocument.Key, BsonDocument.Value>.Index {
        return self.storage.index(after: i)
    }

    public subscript(position: Dictionary<String, BsonDocument.Value>.Index) -> (key: String, value: ExtendedJsonRepresentable) {
        return self.storage[position]
    }

    public var startIndex: Dictionary<Key, Value>.Index {
        return self.storage.startIndex
    }

    public var endIndex: Dictionary<Key, Value>.Index {
        return self.storage.endIndex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ExtendedJsonCodingKeys.self)

        guard let sourceMap = try? container.decode([String: String].self,
                                                    forKey: ExtendedJsonCodingKeys.info) else {
            throw BsonError<BsonDocument>.illegalArgument(
                message: "decoder of type \(decoder) did enough information to map out a new bson document")
        }

        try sourceMap.forEach { (arg) throws in
            let (key, value) = arg
            self[key] = try BsonDocument.decode(from: container,
                                                decodingTypeString: value,
                                                forKey: ExtendedJsonCodingKeys.init(stringValue: key)!)
            orderedKeys.append(key)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ExtendedJsonCodingKeys.self)
        var sourceMap = [String: String]()

        try self.forEach { (arg) in
            let (k, v) = arg

            try BsonDocument.encodeKeyedContainer(to: &container,
                                                  sourceMap: &sourceMap,
                                                  forKey: ExtendedJsonCodingKeys(stringValue: k)!,
                                                  withValue: v)
        }

        if (encoder.userInfo[BSONEncoder.CodingKeys.shouldIncludeSourceMap] as? Bool ?? false) {
            try container.encode(sourceMap, forKey: ExtendedJsonCodingKeys.info)
        }
    }

    // MARK: - Subscript

    /// Accesses the value associated with the given key for reading and writing, like a `Dictionary`.
    /// Document keeps the order of entry while iterating over itskey-value pair.
    /// Writing `nil` removes the stored value from the document and takes O(n), all other read/write action take O(1).
    /// If you wish to set a MongoDB value to `null`, set the value to `NSNull`.
    public subscript(key: String) -> ExtendedJsonRepresentable? {
        get {
            return storage[key]
        }
        set {
            writeQueue.sync {
                if newValue == nil {
                    if let index = orderedKeys.index(of: key) {
                        orderedKeys.remove(at: index)
                    }
                } else if storage[key] == nil {
                    orderedKeys.append(key)
                }

                storage[key] = newValue
            }
        }
    }
}

extension BsonDocument: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, ExtendedJsonRepresentable)...) {
        for (key, value) in elements {
            self[key] = value
            self.orderedKeys.append(key)
        }
    }
}

extension BsonDocument: Equatable {
    public static func ==(lhs: BsonDocument, rhs: BsonDocument) -> Bool {
        let lKeySet = Set(lhs.storage.keys)
        let rKeySet = Set(rhs.storage.keys)
        if lKeySet == rKeySet {
            for key in lKeySet {
                if let lValue = lhs.storage[key], let rValue = rhs.storage[key] {
                    if !lValue.isEqual(toOther: rValue) {
                        return false
                    }
                }
            }
            return true
        }

        return false
    }
}
