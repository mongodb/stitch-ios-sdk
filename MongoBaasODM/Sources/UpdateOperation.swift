//
//  UpdateOperation.swift
//  MongoBaasODM
//
//  Created by Miko Halevi on 5/1/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import MongoCore
import MongoDB
import MongoExtendedJson
import MongoBaasSDKLogger

public struct UpdateOperation <Entity: RootMongoEntity> {
    
    let criteria: Criteria
    let mongoClient: MongoClient
    
    public init(criteria: Criteria, mongoClient: MongoClient) {
        self.criteria = criteria
        self.mongoClient = mongoClient
    }
    
    public func execute(operations operationType: [UpdateOperationType], upsert: Bool = false, multi: Bool = false) -> BaasTask<Any>{
        do{
            
            guard let classMetaData = Utils.entitiesDictionary[Utils.getIdentifier(type: Entity.self)] else{
                printLog(.error, text: "not class meta data found on class: \(Entity.self)")
                throw OdmError.classMetaDataNotFound
            }
            let databaseName = classMetaData.databaseName
            let collectionName = classMetaData.collectionName
            
            let collection = mongoClient.database(named: databaseName).collection(named: collectionName)

           return execute(operations: operationType, collection: collection, upsert: upsert, multi: multi)
        }
        catch{
            return BaasTask<Any>(error: error)
        }
    }
    
    internal func execute(operations operationType: [UpdateOperationType],collection: MongoDB.Collection, upsert: Bool = false, multi: Bool = false) -> BaasTask<Any> {
        let queryDocument = criteria.asDocument
        var updateDocument = Document()
        
        for updateOperation in operationType {
            updateDocument[updateOperation.key] = updateOperation.valueAsDocument
        }
        
        return collection.update(query: queryDocument, update: updateDocument, upsert: upsert, multi: multi)
    }
    
}
