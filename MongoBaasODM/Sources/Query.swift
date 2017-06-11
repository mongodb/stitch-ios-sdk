
//
//  Query.swift
//  MongoBaasODM
//
//  Created by Ofer Meroz on 15/03/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import MongoCore
import MongoExtendedJson
import MongoDB
import MongoBaasSDKLogger

public struct Query<Entity: RootMongoEntity> {
    
    private(set) var criteria: Criteria?
    let mongoClient: MongoClient
    
    private var asDocument: Document {
        return criteria?.asDocument ?? Document()
    }
    
    public init(criteria: Criteria? = nil, mongoClient: MongoClient) {
        self.criteria = criteria
        self.mongoClient = mongoClient
    }
    
    public func count() -> StitchTask<Int> {
        
        do {
            let collection = try getCollection()
            return collection.count(query: asDocument)
        }
        catch {
            return StitchTask<Int>(error: error)
        }
    }
    
    public func find(limit: Int? = nil) -> StitchTask<[Entity]> {
        var projection: Projection?
        if let schema = Entity.schema {
            projection = Projection(schema.map{ return $0.key })
        }
        do{
            let collection = try getCollection()
            return collection.find(query: asDocument, projection: projection?.asDocument, limit: limit).continuationTask{(result: [Document]) -> [Entity] in
                return result.flatMap{ Entity(document: $0, mongoClient: self.mongoClient) }
            }
        }
        catch{
            return StitchTask<[Entity]>(error: error)
        }
    }
    
    public func find(sortParameter: SortParameter, pageSize: Int) -> StitchTask<PaginatedQueryResult<Entity>> {
        return find(originalCriteria: self.criteria, sortParameter: sortParameter, pageSize: pageSize)
    }
    
    internal func find(originalCriteria: Criteria?, sortParameter: SortParameter, pageSize: Int) -> StitchTask<PaginatedQueryResult<Entity>> {
        let pipeline = aggregationPipelineFor(sortParameter: sortParameter, pageSize: pageSize)
        let aggregate = Aggregate<Entity>(mongoClient: mongoClient, stages: pipeline)
        return aggregate.execute().continuationTask{ (result) -> PaginatedQueryResult<Entity> in
            if let bsonArray = result as? BsonArray {
                do {
                    return try PaginatedQueryResult<Entity>(results: bsonArray, originalCriteria: originalCriteria, sortParameter: sortParameter, pageSize: pageSize, mongoClient: self.mongoClient)
                }
            }
            else {
                printLog(.error, text: "Unexpected type was received - expecting BsonArray")
                throw OdmError.corruptedData(message: "Unexpected type was received - expecting BsonArray")
            }
        }
    }
    
    //MARK: Private
    
    private func getTypeMetaData() -> EntityTypeMetaData? {
        return Utils.entitiesDictionary[Utils.getIdentifier(type: Entity.self)]
    }
    
    private func getCollection() throws -> MongoDB.Collection {
        guard let metaData = getTypeMetaData() else {
            printLog(.error, text: "not class meta data found on class: \(Entity.self)")
            throw OdmError.classMetaDataNotFound
        }
        
        let databaseName = metaData.databaseName
        let collectionName = metaData.collectionName

        return mongoClient.database(named: databaseName).collection(named: collectionName)
    }
    
    //MARK: Sort helpers
    
    //Sort is currently not supported at 'collection.find', so we are using aggeegation
    fileprivate func aggregationPipelineFor(sortParameter: SortParameter, pageSize: Int) -> [AggregationStage] {
        var pipeline = [AggregationStage]()
        let matchStage: AggregationStage = .match(query: criteria)
        pipeline.append(matchStage)
        let sortStage: AggregationStage
        //We are adding a secondary sort by _id to get the next items in the pagingation mechanism
        if sortParameter.field != "_id" {
            let idSorter = SortParameter(field: "_id", direction: .ascending)
            sortStage = .sort(sortParameters: [sortParameter, idSorter])
        }
        else {
            sortStage = .sort(sortParameters: [sortParameter])
        }
        pipeline.append(sortStage)
        let limitStage: AggregationStage = .limit(value: pageSize)
        pipeline.append(limitStage)
    
        return pipeline
    }
    
    
}
