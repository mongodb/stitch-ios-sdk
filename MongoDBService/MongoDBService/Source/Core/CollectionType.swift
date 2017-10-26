//
//  CollectionType.swift
//  MongoDBService
//

import Foundation
import StitchCore
import ExtendedJson

public protocol CollectionType {
            
    @discardableResult
    func find(query: BsonDocument, projection: BsonDocument?, limit: Int?) -> StitchTask<[BsonDocument]>
    
    @discardableResult
    func update(query: BsonDocument, update: BsonDocument?, upsert: Bool, multi: Bool) -> StitchTask<Any>
    
    @discardableResult
    func insert(document: BsonDocument) ->  StitchTask<Any>
    
    @discardableResult
    func insert(documents: [BsonDocument]) ->  StitchTask<Any>
    
    @discardableResult
    func delete(query: BsonDocument, singleDoc: Bool) -> StitchTask<Any>
    
    @discardableResult
    func count(query: BsonDocument) -> StitchTask<Int>
    
    @discardableResult
    func aggregate(pipeline: [BsonDocument]) -> StitchTask<Any>
}


// MARK: - Default Values

extension CollectionType {
    
    @discardableResult
    public func find(query: BsonDocument, projection: BsonDocument? = nil, limit: Int? = nil) -> StitchTask<[BsonDocument]> {
        return find(query: query, projection: projection, limit: limit)
    }
    
    @discardableResult
    public func update(query: BsonDocument, update: BsonDocument? = nil, upsert: Bool = false, multi: Bool = false) -> StitchTask<Any> {
        return self.update(query: query, update: update, upsert: upsert, multi: multi)
    }
    
    @discardableResult
    public func delete(query: BsonDocument, singleDoc: Bool = true) -> StitchTask<Any> {
        return delete(query: query, singleDoc: singleDoc)
    }
}
