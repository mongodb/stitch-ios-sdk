//
//  CollectionImpl.swift
//  MongoDB
//
//  Created by Ofer Meroz on 25/05/2017.
//  Copyright © 2017 Mongo. All rights reserved.
//

import Foundation

import MongoCore
import MongoExtendedJson

public struct CollectionImpl: Collection {
    
    private struct Consts {
        static let databaseKey =        "database"
        static let collectionKey =      "collection"
        static let queryKey =           "query"
        static let projectionKey =      "projection"
        static let countKey =           "count"
        static let limitKey =           "limit"
        static let updateKey =          "update"
        static let upsertKey =          "upsert"
        static let multiKey =           "multi"
        static let literalKey =         "literal"
        static let insertKey =          "insert"
        static let itemsKey =           "items"
        static let deleteKey =          "delete"
        static let singleDocKey =       "singleDoc"
        static let aggregateKey =       "aggregate"
        static let pipelineKey =        "pipeline"
    }
    
    private let database: DatabaseImpl
    private let name: String
    
    internal init(database: DatabaseImpl, name: String) {
        self.database = database
        self.name = name
    }
    
    // MARK: - Private
    
    private func createPipeline(action: String, options: [String : JsonExtendable]? = nil) -> Pipeline {
        var args = options ?? [:]
        args[Consts.databaseKey] = database.name
        args[Consts.collectionKey] = name
        return Pipeline(action: action, service: database.client.serviceName, args: args)
    }
    
    private func find(query: Document, projection: Document? = nil, limit: Int?, isCountRequest: Bool) -> BaasTask<Any> {
        var options: [String : JsonExtendable] = [Consts.queryKey : query]
        options[Consts.countKey] = isCountRequest
        if let projection = projection {
            options[Consts.projectionKey] = projection
        }
        
        if let limit = limit {
            options[Consts.limitKey] = limit
        }
        
        return database.client.baasClient.executePipeline(pipeline: createPipeline(action: "find", options: options))
    }
    
    // MARK: - Public
    
    @discardableResult
    public func find(query: Document, projection: Document? = nil, limit: Int? = nil) -> BaasTask<[Document]> {
        return find(query: query, projection: projection, limit: limit, isCountRequest: false).continuationTask(parser: { (result) -> [Document] in
            if let arrayResult = result as? BsonArray {
                return arrayResult.flatMap{$0 as? Document}
            }
            
            throw BaasError.responseParsingFailed(reason: "failed converting result to documents array.")
        })
    }
    
    @discardableResult
    public func update(query: Document, update: Document? = nil, upsert: Bool = false, multi: Bool = false) -> BaasTask<Any> {
        var options: [String : JsonExtendable] = [Consts.queryKey : query]
        if let update = update {
            options[Consts.updateKey] = update
        }
        options[Consts.upsertKey] = upsert
        options[Consts.multiKey] = multi
        return database.client.baasClient.executePipeline(pipeline: createPipeline(action: Consts.updateKey, options: options))
    }
    
    @discardableResult
    public func insert(document: Document) ->  BaasTask<Any> {
        return insert(documents: [document])
    }
    
    @discardableResult
    public func insert(documents: [Document]) ->  BaasTask<Any> {
        var piplines: [Pipeline] = []
        piplines.append(Pipeline(action: Consts.literalKey, args: [Consts.itemsKey : BsonArray(array: documents)]))
        piplines.append(createPipeline(action: Consts.insertKey))
        return database.client.baasClient.executePipeline(pipelines: piplines)
    }
    
    @discardableResult
    public func delete(query: Document, singleDoc: Bool = true) -> BaasTask<Any> {
        var options: [String : JsonExtendable] = [Consts.queryKey : query]
        options[Consts.singleDocKey] = singleDoc
        return database.client.baasClient.executePipeline(pipeline: createPipeline(action: Consts.deleteKey, options: options))
    }
    
    @discardableResult
    public func count(query: Document) -> BaasTask<Int> {
        return find(query: query, limit: nil, isCountRequest: true).continuationTask(parser: { (result) -> Int in
            if let arrayResult = result as? BsonArray,
                let intResult = arrayResult.first as? Int {
                return intResult
            }
            
            throw BaasError.responseParsingFailed(reason: "failed converting result to documents array.")
        })
    }
    
    @discardableResult
    public func aggregate(pipeline: [Document]) -> BaasTask<Any> {
        let options: [String : JsonExtendable] = [Consts.pipelineKey : BsonArray(array: pipeline)]
        return database.client.baasClient.executePipeline(pipeline: createPipeline(action: Consts.aggregateKey, options: options))
    }
}
