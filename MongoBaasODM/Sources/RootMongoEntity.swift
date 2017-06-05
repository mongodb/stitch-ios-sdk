//
//  RootMongoEntity.swift
//  MongoBaasODM
//
//  Created by Ofer Meroz on 17/03/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import MongoExtendedJson
import MongoDB
import MongoCore
import MongoBaasSDKLogger

open class RootMongoEntity: BaseMongoEntity {
    
    //MARK: Properties
    
    var mongoClient: MongoClient
    
    private var collection: MongoDB.Collection? {
        if let classMetaData = self.getEntityMetaData(){
            let databaseName = classMetaData.databaseName
            let collectionName = classMetaData.collectionName
            return mongoClient.database(named:databaseName).collection(named:collectionName)
        }
        return nil;
    }
        
    //MARK: Init
    
    required public init(document: Document = Document(), mongoClient: MongoClient) {
        self.mongoClient = mongoClient
        super.init(document: document)
    }

    //MARK: Static getters
    

    internal static var schema: [String : EntityIdentifier]? {
        
        let classIdentifier = EntityIdentifier(self)
        
        if let entityTypeMetaData = Utils.entitiesDictionary[classIdentifier]{
                return entityTypeMetaData.getSchema()
        }
        return nil
    }
    
    //MARK: Public
    
    public func save() -> MongoCore.BaasTask<Any> {
        if let collection = collection{
            return collection.insert(document: self.asDocument()).response(completionHandler: { baasResult in
                if let bsonArray = baasResult.value as? BsonArray , let document = bsonArray.first as? Document, let objectId = document[Utils.Consts.objectIdKey] as? ObjectId  {
                    self.objectId = objectId
                }
            })
        }
        let error = OdmError.classMetaDataNotFound
        return MongoCore.BaasTask(error: error)
    }
    
    public func update() -> MongoCore.BaasTask<Any> {
      return update(operationTypes: nil, operationTypePrefix: nil, embeddedEntityInArrayObjectId: nil)
    }
    
    public func delete() -> MongoCore.BaasTask<Any> {
        let error: OdmError
        if let entityId = self.objectId{
            let queryDocument = Document(key: Utils.Consts.objectIdKey, value: entityId)
            if let collection = collection{
              return collection.delete(query: queryDocument, singleDoc: true)
            }
            else{
                error = OdmError.classMetaDataNotFound
            }
        }
        else{
            printLog(.error, text: "trying to delete an entity without object id")
            error = OdmError.objectIdNotFound
            return MongoCore.BaasTask(error: error)
        }

        return MongoCore.BaasTask(error: error)
    }
    
    //MARK: Internal
    
    override internal func update(operationTypes: [UpdateOperationType]?, operationTypePrefix: String?, embeddedEntityInArrayObjectId: ObjectId?) -> BaasTask<Any> {
        let error: OdmError
        var updateTypesToReturn = operationTypes ?? getUpdateOperationTypes()
        
        if let entityId = self.objectId{
            
            var criteriaToReturn = Criteria.equals(field: Utils.Consts.objectIdKey, value: entityId)
            if let embeddedEntityInArrayObjectId = embeddedEntityInArrayObjectId, let operationTypePrefix = operationTypePrefix {
                
                let embeddedEntityFieldName = operationTypePrefix.replacingOccurrences(of: ".$", with: "") + Utils.Consts.objectIdKey
                let embeddedEntityCriteria = Criteria.equals(field: embeddedEntityFieldName, value: embeddedEntityInArrayObjectId)
                criteriaToReturn = criteriaToReturn && embeddedEntityCriteria
            }
            
            if let operationTypePrefix = operationTypePrefix {
                updateTypesToReturn = embedPrefixIn(operationTypes: updateTypesToReturn, prefix: operationTypePrefix)
            }
            return executeUpdate(operationTypes: updateTypesToReturn, criteria: criteriaToReturn)

        }
            
        else{
            
            printLog(.error, text: "trying to update an entity without object id")
            error = OdmError.objectIdNotFound
        }
        
        return MongoCore.BaasTask(error: error)
    }
    
    //MARK: Private
    
    private func getEntityMetaData() -> EntityTypeMetaData?{
        let myType = type(of: self)
        return Utils.entitiesDictionary[Utils.getIdentifier(type:myType)]
    }
    
    private func createEntityCriteria() -> Criteria? {
        if let entityId = self.objectId {
            return Criteria.equals(field: Utils.Consts.objectIdKey, value: entityId)
        }
        return nil
    }
    
    private func embedPrefixIn(operationTypes: [UpdateOperationType], prefix: String) -> [UpdateOperationType] {
        var mutatedOperationTypes: [UpdateOperationType] = []
        
        for operationType in operationTypes {
            var tempOprationType = operationType
            tempOprationType.add(prefix: prefix)
            mutatedOperationTypes.append(tempOprationType)
        }
        
        return mutatedOperationTypes
    }
    
    private func executeUpdate(operationTypes: [UpdateOperationType], criteria: Criteria) ->BaasTask<Any> {
        let error: OdmError
        
        if let collection = collection {
            
            let updateOperation = UpdateOperation(criteria: criteria, mongoClient: mongoClient)
            return updateOperation.execute(operations: operationTypes, collection: collection)
        }
        else{
            print("trying to update without a class metadata registration")
            error = OdmError.classMetaDataNotFound
            return MongoCore.BaasTask(error: error)
        }
    }

}
