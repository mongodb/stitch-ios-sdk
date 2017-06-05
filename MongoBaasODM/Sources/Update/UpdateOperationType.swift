//
//  UpdateOperationType.swift
//  MongoBaasODM
//
//  Created by Miko Halevi on 5/3/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import MongoExtendedJson

public enum UpdateOperationType {
    
    case set([String : JsonExtendable?])
    case unset([String : JsonExtendable?])
    case push([String : JsonExtendable?])
    case pull([String : JsonExtendable?])
    
    //MARK: Private
    
    private struct Consts{
        static let updateEntrySetKey   = "$set"
        static let updateEntryUnsetKey = "$unset"
        static let updateEntryPushKey  = "$push"
        static let updateEntryPullKey  = "$pull"
    }
    
    private func changePrefixWith(prefix: String, dictionary: [String : JsonExtendable?]) -> [String : JsonExtendable?] {
        var newValuesDict = [String : JsonExtendable?]()
        
        for (key, value) in dictionary {
            let newKey = prefix + key
            newValuesDict[newKey] = value
        }
        
        return newValuesDict
    }
    
    //MARK: Internal
    
    internal var key: String {
        switch self {
        case .set:
            return Consts.updateEntrySetKey
        case .unset:
            return Consts.updateEntryUnsetKey
        case .push:
            return Consts.updateEntryPushKey
        case .pull:
            return Consts.updateEntryPullKey
        }
        
    }
    
    internal var valueAsDocument: Document {
        switch self {
        case .set(let value):
            return Document(dictionary: value)
        case .unset(let value):
            return Document(dictionary: value)
        case .push(let value):
            return Document(dictionary: value)
        case .pull(let value):
            return Document(dictionary: value)
        }
    }
    
    internal mutating func add(prefix: String) {
        switch self {
        case .set(let value):
            self = .set(changePrefixWith(prefix: prefix, dictionary: value))
        case .unset(let value):
            self = .unset(changePrefixWith(prefix: prefix, dictionary: value))
        case .push(let value):
            self = .push(changePrefixWith(prefix: prefix, dictionary: value))
        case .pull(let value):
            self = .pull(changePrefixWith(prefix: prefix, dictionary: value))
        }
    }
    
}
