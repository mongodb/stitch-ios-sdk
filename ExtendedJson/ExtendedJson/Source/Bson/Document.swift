//
//  Document.swift
//  ExtendedJson
//

import Foundation

public struct Document : Collection {
    public typealias Element = (key: String, value: ExtendedJsonRepresentable)

    fileprivate var storage: [String : ExtendedJsonRepresentable] = [:]
    fileprivate var orderedKeys: [String] = []

    private let writeQueue = DispatchQueue.global(qos: .utility)
    
    public init() {
    }
    
    public init(key: String, value: ExtendedJsonRepresentable) throws {
        self[key] = try Document.read(value: value)
    }
    
    public init(dictionary: [String: ExtendedJsonRepresentable?]){
        for (key, value) in dictionary {
            let concreteValue = value ?? NSNull()
            self[key] = concreteValue
        }
    }
    
    public init(extendedJson json: [String : Any]) throws {
        for (key, value) in json {
            self[key] = try Document.read(value: value)
        }
    }
    
    public static func read(value: Any) throws -> ExtendedJsonRepresentable {
        switch (value) {
        case let json as [String : Any]:
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
                    }
                }
            }
            
            return try Document(extendedJson: json)
        case is [Any]:
            return try BsonArray.fromExtendedJson(xjson: value)
        case is String:
            return try String.fromExtendedJson(xjson: value)
        case is Bool:
            return try Bool.fromExtendedJson(xjson: value)
        case is NSNull:
            return try NSNull.fromExtendedJson(xjson: value)
        default:
            throw BsonError.parseValueFailure(value: value, attemptedType: Document.self)
        }
    }
    
    public func index(after i: Dictionary<Document.Key, Document.Value>.Index) -> Dictionary<Document.Key, Document.Value>.Index {
        return self.storage.index(after: i)
    }
    
    public subscript(position: Dictionary<String, Document.Value>.Index) -> (key: String, value: ExtendedJsonRepresentable) {
        return self.storage[position]
    }
    
    public var startIndex: Dictionary<Key, Value>.Index {
        return self.storage.startIndex
    }
    
    public var endIndex: Dictionary<Key, Value>.Index {
        return self.storage.endIndex
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
                }
                else if storage[key] == nil {
                    orderedKeys.append(key)
                }
                
                storage[key] = newValue
            }
        }
    }
}

extension Document: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, ExtendedJsonRepresentable)...) {
        for (key, value) in elements {
            self[key] = value
        }
    }
}

extension Document: Equatable {
    
    public static func ==(lhs: Document, rhs: Document) -> Bool {
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

