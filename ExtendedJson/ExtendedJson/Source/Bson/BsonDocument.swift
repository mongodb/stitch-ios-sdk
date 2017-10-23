//
//  Document.swift
//  ExtendedJson
//

import Foundation

public class BsonEncoder: JSONEncoder {
    public override func encode<T>(_ value: T) throws -> Data where T : Encodable {
        switch value {
        case let value as BsonDocument:
            guard let data = try? JSONSerialization.data(withJSONObject: value.toExtendedJson) else {
                fallthrough
            }
            return data
        default: return try super.encode(value)
        }
    }
}
public class BsonDecoder: JSONDecoder {
    public override func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
        switch type {
        case is BsonDocument.Type:
            guard let values = try JSONSerialization.jsonObject(with: data,
                                                                options: .allowFragments) as? [String: Any?],
                let doc = try? BsonDocument(extendedJson: values) else {
                fallthrough
            }
            return doc as! T
        default: return try super.decode(type, from: data)
        }
    }
}

public struct BsonDocument: Codable, Collection {
    public typealias Element = (key: String, value: ExtendedJsonRepresentable)

    fileprivate var storage: [String: ExtendedJsonRepresentable] = [:]
    fileprivate var orderedKeys: [String] = []

    private let writeQueue = DispatchQueue.global(qos: .utility)

    public init() {
    }

    public init(key: String, value: ExtendedJsonRepresentable) throws {
        self[key] = try BsonDocument.decodeXJson(value: value)
    }

    public init(dictionary: [String: ExtendedJsonRepresentable?]) {
        for (key, value) in dictionary {
            self[key] = value ?? nil
        }
    }

    public init(extendedJson json: [String: Any?]) throws {
        for (key, value) in json {
            self[key] = try BsonDocument.decodeXJson(value: value)
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

        var infoContainer = try container.superDecoder(forKey: ExtendedJsonCodingKeys.info)

        try container.allKeys.forEach { key in
            let nested = try container.decode([String: [String: String]].self, forKey: key)
            print(nested)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if let encoder = encoder as? JSONEncoder {
            try encoder.encode(JSONSerialization.data(withJSONObject: self))
            return
        }
        
        var container = encoder.container(keyedBy: ExtendedJsonCodingKeys.self)
        //var infoEncoder = container.nestedContainer(keyedBy: ExtendedJsonCodingKeys.self, forKey: ExtendedJsonCodingKeys.info)
        var infoContainer = [String: String]()
        try self.forEach { (arg) in
            let (k, v) = arg

            try BsonDocument.encode(to: &container,
                                    encodingInfo: &infoContainer,
                                    forKey: ExtendedJsonCodingKeys(stringValue: k)!,
                                    withValue: v)
        }
        //try container.encode(infoContainer, forKey: ExtendedJsonCodingKeys.info)
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
