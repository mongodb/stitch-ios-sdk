//
//  BsonArray.swift
//  MongoExtendedJson
//
//  Created by Ofer Meroz on 01/03/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public struct BsonArray {
    
    fileprivate var underlyingArray: [JsonExtendable] = []
    
    public init(){}
    
    public init(array: [JsonExtendable]) {
        underlyingArray = array
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
    
    public func makeIterator() -> IndexingIterator<[JsonExtendable]> {
        return underlyingArray.makeIterator()
    }
    
    public subscript(index:Int) -> JsonExtendable {
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
    
    public mutating func append(_ newElement: JsonExtendable) {
        underlyingArray.append(newElement)
    }
    
    public mutating func remove(at index: Int) {
        underlyingArray.remove(at: index)
    }
}

extension BsonArray: ExpressibleByArrayLiteral{
    public init(arrayLiteral elements: JsonExtendable...) {
        self.init()
        underlyingArray = elements
    }
}
