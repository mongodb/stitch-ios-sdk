//
//  Collection.swift
//  MongoDB
//
//  Created by Ofer Meroz on 09/02/2017.
//  Copyright © 2017 Mongo. All rights reserved.
//

import Foundation
import MongoCore
import MongoExtendedJson

public protocol Collection {
            
    @discardableResult
    func find(query: Document, projection: Document?, limit: Int?) -> BaasTask<[Document]>
    
    @discardableResult
    func update(query: Document, update: Document?, upsert: Bool, multi: Bool) -> BaasTask<Any>
    
    @discardableResult
    func insert(document: Document) ->  BaasTask<Any>
    
    @discardableResult
    func insert(documents: [Document]) ->  BaasTask<Any>
    
    @discardableResult
    func delete(query: Document, singleDoc: Bool) -> BaasTask<Any>
    
    @discardableResult
    func count(query: Document) -> BaasTask<Int>
    
    @discardableResult
    func aggregate(pipeline: [Document]) -> BaasTask<Any>
}


// MARK: - Default Values

extension Collection {
    
    @discardableResult
    public func find(query: Document, projection: Document? = nil, limit: Int? = nil) -> BaasTask<[Document]> {
        return find(query: query, projection: projection, limit: limit)
    }
    
    @discardableResult
    public func update(query: Document, update: Document? = nil, upsert: Bool = false, multi: Bool = false) -> BaasTask<Any> {
        return self.update(query: query, update: update, upsert: upsert, multi: multi)
    }
    
    @discardableResult
    public func delete(query: Document, singleDoc: Bool = true) -> BaasTask<Any> {
        return delete(query: query, singleDoc: singleDoc)
    }
}
