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
    
    @discardableResult
    public func save() -> MongoCore.StitchTask<Any> {
        if let collection = collection {
            return collection.insert(document: asDocument).response(completionHandler: { stitchResult in
                if let bsonArray = stitchResult.value as? BsonArray , let document = bsonArray.first as? Document, let objectId = document[Utils.Consts.objectIdKey] as? ObjectId  {
                    self.objectId = objectId
                    self.handleOperationResult(stitchResult: stitchResult)
                }
            })
        }
        let error = OdmError.classMetaDataNotFound
        return MongoCore.StitchTask(error: error)
    }
    
    @discardableResult
    public func update() -> MongoCore.StitchTask<Any> {
      return update(operationTypes: nil, operationTypePrefix: nil, embeddedEntityInArrayObjectId: nil).response(completionHandler: { (result) in
        self.handleOperationResult(stitchResult: result)
      })
    }
    
    @discardableResult
    public func delete() -> MongoCore.StitchTask<Any> {
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
            return MongoCore.StitchTask(error: error)
        }

        return MongoCore.StitchTask(error: error)
    }
    
    //MARK: Internal
    
    override internal func update(operationTypes: [UpdateOperationType]?, operationTypePrefix: String?, embeddedEntityInArrayObjectId: ObjectId?) -> StitchTask<Any> {
        let error: OdmError
        var updateTypesToReturn = operationTypes ?? getUpdateOperationTypes()
        
        if let entityId = self.objectId{
            
            var criteriaToReturn = Criteria.equals(field: Utils.Consts.objectIdKey, value: entityId)
            // for embedded entity that is part of an array
            if let embeddedEntityInArrayObjectId = embeddedEntityInArrayObjectId, let operationTypePrefix = operationTypePrefix {
                
                let embeddedEntityFieldName = operationTypePrefix.replacingOccurrences(of: ".$", with: "") + Utils.Consts.objectIdKey
                let embeddedEntityCriteria = Criteria.equals(field: embeddedEntityFieldName, value: embeddedEntityInArrayObjectId)
                criteriaToReturn = criteriaToReturn && embeddedEntityCriteria
            }
            
            // for embedded entity that is held in a simple property
            if let operationTypePrefix = operationTypePrefix {
                updateTypesToReturn = embedPrefixIn(operationTypes: updateTypesToReturn, prefix: operationTypePrefix)
            }
            return executeUpdate(operationTypes: updateTypesToReturn, criteria: criteriaToReturn)
        }
            
        else{
            printLog(.error, text: "trying to update an entity without object id")
            error = OdmError.objectIdNotFound
        }
        
        return MongoCore.StitchTask(error: error)
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
    
    private func isOperationsContainTwoArrayUpdateOperation(operations: [UpdateOperationType]) -> Bool {
        return operations.contains(.pull([:])) && operations.contains(.push([:]))
    }
    
    
    
    private func executeUpdate(operationTypes: [UpdateOperationType], criteria: Criteria) ->StitchTask<Any> {
        if let collection = collection {
            
            let updateOperation = UpdateOperation(criteria: criteria, mongoClient: mongoClient)
            
            var firstUpdateOperation = operationTypes
            var secondUpdateOperation: [UpdateOperationType]?
            
            let operationContainsTwoArrays = operationTypes.contains(.pull([:])) && operationTypes.contains(.push([:]))
            
            if operationContainsTwoArrays {
                // split the calls to two calls - push operation as the second operation
                if let indexOfPush = firstUpdateOperation.index(where: { $0 == UpdateOperationType.pull([:]) }) {
                    let pushOperation = firstUpdateOperation.remove(at: indexOfPush)
                    secondUpdateOperation = [pushOperation]
                }
            }
            
            // pull & push are both in update operation - pull will execute second
            if let secondUpdateOperation = secondUpdateOperation {
                let finalTask = StitchTask<Any>()
                
                updateOperation.execute(operations: firstUpdateOperation, collection: collection).response(onQueue: DispatchQueue.global(qos: .utility), completionHandler: { (firstResult) in
                    switch (firstResult) {
                    case .success(_):
                        updateOperation.execute(operations: secondUpdateOperation, collection: collection).response(completionHandler: { (secondResult) in
                            switch (secondResult) {
                            case .success(_):
                                finalTask.result = secondResult
                            case .failure(let error):
                                finalTask.result = .failure(OdmError.partialUpdateSuccess(originalError: error))
                            }
                        })
                    case .failure(_):
                        finalTask.result = firstResult
                    }
                    
                })
                
                return finalTask
            }
            
                //regular execution
            else {
                return updateOperation.execute(operations: firstUpdateOperation, collection: collection)
            }
            
        }
        else{
            print("trying to update without a class metadata registration")
            let error = OdmError.classMetaDataNotFound
            return MongoCore.StitchTask(error: error)
        }
    }

}
