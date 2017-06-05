//
//  Aggregate.swift
//  MongoBaasODM
//
//  Created by Yanai Rozenberg on 09/05/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import MongoCore
import MongoDB
import MongoExtendedJson
import MongoBaasSDKLogger

public struct Aggregate<Entity: RootMongoEntity> {
    let mongoClient: MongoClient
    var aggregationPipeline: [AggregationStage]
    
    public init(mongoClient: MongoClient, stages: [AggregationStage]) {
        self.mongoClient = mongoClient
        self.aggregationPipeline = stages
    }
    
    public func execute() -> BaasTask<Any> {
        if let classMetaData = Utils.entitiesDictionary[Utils.getIdentifier(type: Entity.self)] {
            
            let databaseName = classMetaData.databaseName
            let collectionName = classMetaData.collectionName
            
            let aggregationPipelineDocument = aggregationPipeline.map{ $0.asDocument }
            return mongoClient.database(named: databaseName).collection(named: collectionName).aggregate(pipeline: aggregationPipelineDocument)
        }
        else {
            printLog(.error, text: "Metadata is missing for class \(Entity.self)")
            return BaasTask<Any>(error: OdmError.classMetaDataNotFound)
        }
    }
    
}
