//
//  BaseMongoEntity.swift
//  MongoBaasODM
//
//  Created by Ofer Meroz on 17/03/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import MongoExtendedJson
import MongoCore

open class BaseMongoEntity : JsonExtendable {
    
    //MARK: Properties
    
    internal var properties: [String : JsonExtendable?] = [:]
    internal var modifiedProperties: [String : JsonExtendable?] = [:]
    
    private var arrayRemovals: [String : [JsonExtendable]] = [:]
    private var arrayAdditionals: [String : [JsonExtendable]] = [:]
    
    //MARK: Init
    
    public init(document: Document) {
        let myClassIdentifier = Utils.getIdentifier(any: self)
        if let myEntityMetadata = Utils.entitiesDictionary[myClassIdentifier]{
            
            for (key, value) in document{
                if let value = value as? Document {
                    if let propertyObjectIdentifier = myEntityMetadata.getSchema()[key], let embeddedEntityMetaData = Utils.entitiesDictionary[propertyObjectIdentifier] {
                        let embeddedEntityValue = embeddedEntityMetaData.create(document: value)
                        
                        embeddedEntityValue?.embedIn(parent: self, keyInParent: key, isEmbeddedInArray: false)
                        properties[key] = embeddedEntityValue
                    }
                }
                else if let value = value as? BsonArray {
                    var bsonArray = BsonArray()
                    
                    for item in value{
                        if let item = item as? Document {
                            
                            if let propertyObjectIdentifier = myEntityMetadata.getSchema()[key], let embeddedEntityMetaData = Utils.entitiesDictionary[propertyObjectIdentifier] {
                                if let embeddedEntityValue = embeddedEntityMetaData.create(document: item){
                                    embeddedEntityValue.embedIn(parent: self, keyInParent: key, isEmbeddedInArray: true)
                                    bsonArray.append(embeddedEntityValue)
                                }
                            }
                        }
                        else{
                            bsonArray.append(item)
                        }
                    }
                    properties[key] = bsonArray
                    
                }
            
                else if value is NSNull{
                    properties[key] = nil
                }
                    
                else{
                    properties[key] = value
                }
            }
        }
    }
    
    //MARK: Public properties
    
    internal(set) public var objectId: MongoExtendedJson.ObjectId? {
        get{
            if let objectId = self[Utils.Consts.objectIdKey] as? ObjectId {
                return objectId
            }
            return nil
        }
         set(newObjectId){
            if let newObjectId = newObjectId{
                self[Utils.Consts.objectIdKey] = newObjectId
            }
        }
    }
    
    //MARK: Inherit - Consider use protocols instead
    
    internal func update(operationTypes: [UpdateOperationType]?, operationTypePrefix: String?, embeddedEntityInArrayObjectId: ObjectId?) -> BaasTask<Any> {
        let error = OdmError.classMetaDataNotFound
        return MongoCore.BaasTask(error: error)
    }
    
    internal func getUpdateOperationTypes() -> [UpdateOperationType] {
        var result: [UpdateOperationType] = []
    
        var setDictionary: [String : JsonExtendable] = [:]
        var unsetDictionary: [String : JsonExtendable] = [:]
        var pushDictionary: [String : JsonExtendable] = [:]
        var pullDictionary: [String : JsonExtendable] = [:]

        let ignoreSet: Set<String> = arrayRemovals.keys + arrayAdditionals.keys
        
        for (key,value) in arrayAdditionals {
           pushDictionary[key] = BsonArray(array: value)
        }
        
        for (key,value) in arrayRemovals {
            if value.first is EmbeddedMongoEntity {
                var criteria: Criteria?
                for entity in value {
                    if let entity = entity as? EmbeddedMongoEntity, let objectId = entity.objectId {
                        criteria = criteria || .equals(field: Utils.Consts.objectIdKey, value: objectId)
                    }
                }
                pullDictionary[key] = criteria?.asDocument
            } else {
                pullDictionary[key] = Document(key: "$in", value: BsonArray(array: value))
            }
        }
        
        for (key,value) in modifiedProperties {
            
            if ignoreSet.contains(key) {
                continue
            }
            
            if value == nil {
                unsetDictionary[key] = ""
            }
            else  {
                setDictionary[key] = value
            }
        }
        
        if !setDictionary.isEmpty {
            result.append(.set(setDictionary))
        }
        if !pushDictionary.isEmpty {
            result.append(.push(pushDictionary))
        }
        if !pullDictionary.isEmpty {
            result.append(.pull(pullDictionary))
        }
        if !unsetDictionary.isEmpty {
            result.append(.unset(unsetDictionary))
        }
      
        
        return result
    }



    //MARK: subscript
    
    public subscript(key: String) -> JsonExtendable?{
        get{
            if let value = modifiedProperties[key] {
                return value
            }
            if let value = properties[key]{
                return value
            }
            return nil
        }
        set{
            modifiedProperties[key] = newValue
            if let newValue = newValue as? EmbeddedMongoEntity{
                newValue.embedIn(parent: self, keyInParent: key, isEmbeddedInArray: false)
            }
        }
        
    }
    
    //MARK: Document
    
    func asDocument() -> Document{
        var document = Document()
        var deletedKeys: [String] = []
        
        for (key, value) in modifiedProperties {
            if value == nil {
                deletedKeys.append(key)
            }
            else {
                document[key] = value
            }
        }
        
        for (key, value) in properties{
            if document[key] == nil, value != nil,  !deletedKeys.contains(key) {
                document[key] = value
            }
        }
        return document
    }
    
    //MARK: JsonExtendable
    
     public var toExtendedJson: Any{
        return asDocument().toExtendedJson
    }
    
    //MARK: Static Registration
    
    public static func registerClass(entityMetaData: EntityTypeMetaData)  {
        let classIdentifier = entityMetaData.getEntityIdentifier()
        Utils.entitiesDictionary[classIdentifier] = entityMetaData
    }
    
}
