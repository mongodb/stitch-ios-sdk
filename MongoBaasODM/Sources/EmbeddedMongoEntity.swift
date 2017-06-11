//
//  EmbeddedMongoEntity.swift
//  MongoBaasODM
//
//  Created by Miko Halevi on 3/20/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import UIKit
import MongoExtendedJson
import MongoCore

open class EmbeddedMongoEntity: BaseMongoEntity {

    var parent: BaseMongoEntity?
    var keyInParent: String?
    var isEmbeddedInArray: Bool? {
        willSet(embeddedInArray) {
            if embeddedInArray == true{
                setObjectIdIfNeeded()
            }
        }
    }

    public override init(document: Document) {
        super.init(document: document)
    }
    
    public override init(){
        super.init()
    }
    
    //MARK: Private
    
    private func setObjectIdIfNeeded() {
        if (self.objectId == nil){
            self.objectId = ObjectId()
        }
    }
    
    //MARK: Public
    
    @discardableResult
    public func update() -> MongoCore.StitchTask<Any> {
        return update(operationTypes: nil, operationTypePrefix: nil, embeddedEntityInArrayObjectId: nil).response(completionHandler: { (result) in
            self.handleOperationResult(stitchResult: result)
        })
    }
    
    //MARK: Internal
    
    internal func embedIn(parent baseMongoEntity: BaseMongoEntity, keyInParent: String, isEmbeddedInArray: Bool){
        parent = baseMongoEntity
        self.keyInParent = keyInParent
        self.isEmbeddedInArray = isEmbeddedInArray
    }
    
    override internal func update(operationTypes: [UpdateOperationType]?, operationTypePrefix: String?, embeddedEntityInArrayObjectId: ObjectId?) -> StitchTask<Any> {
        
        let updateTypesToReturn = operationTypes ?? getUpdateOperationTypes()
        var prefixToReturn = operationTypePrefix ?? ""
        var objectIdToReturn: ObjectId?
        
        guard let keyInParent = keyInParent,
            let parent = parent,
            let isEmbeddedInArray = isEmbeddedInArray else {
            let error = OdmError.updateParametersMissing
            return MongoCore.StitchTask(error: error)
        }
        
        let prefixToAdd = isEmbeddedInArray ? ".$." : "."
        prefixToReturn = keyInParent + prefixToAdd + prefixToReturn
        
        
        if isEmbeddedInArray && embeddedEntityInArrayObjectId == nil {
            if let objectId = objectId {
                objectIdToReturn = objectId
            }
            else{
                return StitchTask(error: OdmError.objectIdNotFound)
            }
        }
        
        return parent.update(operationTypes: updateTypesToReturn, operationTypePrefix: prefixToReturn, embeddedEntityInArrayObjectId: objectIdToReturn)
    }
    
}
