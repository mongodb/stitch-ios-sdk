//
//  PaginatedQueryResult.swift
//  MongoBaasODM
//
//  Created by Yanai Rozenberg on 16/05/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import MongoCore
import MongoExtendedJson
import MongoDB
import MongoBaasSDKLogger

public struct PaginatedQueryResult<Entity: RootMongoEntity> {
    fileprivate let rawResults: BsonArray
    fileprivate let sortParameter: SortParameter
    fileprivate let originalCriteria: Criteria?
    fileprivate let mongoClient: MongoClient
    fileprivate let pageSize: Int
    
    public let results: [Entity]
    fileprivate(set) public var hasNext: Bool = false

    //The original criteria is being modified to get the next results page
    init(results: BsonArray, originalCriteria: Criteria?, sortParameter: SortParameter, pageSize: Int, mongoClient: MongoClient) throws {
        self.rawResults = results
        self.sortParameter = sortParameter
        self.originalCriteria = originalCriteria
        self.mongoClient = mongoClient
        self.pageSize = pageSize
        if results.count > 0 {
            let entitiesArray: [Entity] = try results.map({ (item) -> Entity in
                if let entityDoc = item as? Document {
                    return Entity(document: entityDoc, mongoClient: mongoClient)
                }
                else {
                    let errString = "Unexpected type was received - expecting a document. Recieved: \(item)"
                    printLog(.error, text: errString)
                    throw OdmError.corruptedData(message: errString)
                }
            })
            self.results = entitiesArray
            self.hasNext = !(entitiesArray.count < pageSize)
        }
        else {
            self.results = [Entity]()
        }
    }
    
    public func nextPage() -> BaasTask<PaginatedQueryResult<Entity>> {
        if results.count > 0 {
            let lastItem: Document? = rawResults[rawResults.endIndex - 1] as? Document
            if let lastRootDocument = lastItem {
                var lastEmbededEntityDocument = lastRootDocument
                let sortedFields = sortParameter.field.components(separatedBy: ".")
                for field in sortedFields.dropLast() {
                    if let embededEntityDocument = lastEmbededEntityDocument[field] as? Document {
                        lastEmbededEntityDocument = embededEntityDocument
                    }
                    else {
                        let errString = "Embeded document in sort field is corrupted \(field)"
                        printLog(.error, text: errString)
                        return BaasTask<PaginatedQueryResult<Entity>>(error: OdmError.corruptedData(message: errString))
                    }
                }
                if let objectId = lastRootDocument["_id"], let lastSortFieldValue = lastEmbededEntityDocument[sortedFields[sortedFields.endIndex-1]] {
                    let newCriteria = newCriteriaForPagination(originalCriteria: originalCriteria, sortParameter: sortParameter, lastSortFieldValue: lastSortFieldValue, objectId: objectId)
                    let nextPageQuery = Query<Entity>(criteria: newCriteria, mongoClient: mongoClient)
                    return nextPageQuery.find(originalCriteria: originalCriteria, sortParameter: sortParameter, pageSize: pageSize)
                }
                else {
                    let errString = "objectId or last field are invalid"
                    printLog(.error, text: errString)
                    return BaasTask<PaginatedQueryResult<Entity>>(error: OdmError.corruptedData(message: errString))
                }
            }
            else {
                let errString = "Unexpected type was received - expecting a document"
                printLog(.error, text: errString)
                return BaasTask<PaginatedQueryResult<Entity>>(error: OdmError.corruptedData(message: errString))
            }
        }
        
        return BaasTask<PaginatedQueryResult<Entity>>(error: OdmError.collectionOutOfRange)
    }
    
    fileprivate func newCriteriaForPagination(originalCriteria: Criteria?, sortParameter: SortParameter, lastSortFieldValue: JsonExtendable, objectId: JsonExtendable) -> Criteria {
        var newCriteria: Criteria
        switch sortParameter.direction {
        case .ascending:
            if sortParameter.field != "_id" {
                newCriteria = .greaterThan(field: sortParameter.field, value: lastSortFieldValue) || (.equals(field: sortParameter.field, value: lastSortFieldValue) && .greaterThan(field: "_id", value: objectId))
            }
            else {
                newCriteria = .greaterThan(field: sortParameter.field, value: lastSortFieldValue)
            }
            
        case .descending:
            if sortParameter.field != "_id" {
                newCriteria = .lessThan(field: sortParameter.field, value: lastSortFieldValue) || (.equals(field: sortParameter.field, value: lastSortFieldValue) && .greaterThan(field: "_id", value: objectId))
            }
            else {
                newCriteria = .lessThan(field: sortParameter.field, value: lastSortFieldValue)
            }
        }
        if let originalCriteria = originalCriteria {
            newCriteria = originalCriteria && newCriteria
        }
        
        return newCriteria
    }
}
