//
//  UpdateOperationTests.swift
//  MongoDBODM
//
//  Created by Ofir Zucker on 06/06/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import XCTest
@testable import MongoDBODM
import ExtendedJson
import MongoDBService
@testable import StitchCore

class UpdateOperationTests: XCTestCase {
    
    static let serviceName = "serviceName"
    static let dbName = "db"
    static let collectionName = "collection"
    
    static let fieldKey = "fieldKey"
    static let operationValue: Int = 1
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testUpdateOperationTypeSet() {
        let updateOperationType = UpdateOperationType.set([ UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        testUpdateOperations(types: [updateOperationType])
    }
    
    func testUpdateOperationTypeUnset() {
        let updateOperationType = UpdateOperationType.unset([ UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        testUpdateOperations(types: [updateOperationType])
    }
    
    func testUpdateOperationTypePush() {
        let updateOperationType = UpdateOperationType.push([ UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        testUpdateOperations(types: [updateOperationType])
    }
    
    func testUpdateOperationTypePull() {
        let updateOperationType = UpdateOperationType.pull([ UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        testUpdateOperations(types: [updateOperationType])
    }
    
    func testUpdateOperationTypeInc() {
        let updateOperationType = UpdateOperationType.inc([ UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        testUpdateOperations(types: [updateOperationType])
    }

    func testUpdateOperationTypeMul() {
        let updateOperationType = UpdateOperationType.mul([ UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        testUpdateOperations(types: [updateOperationType])
    }
    
    func testUpdateOperationTypeMin() {
        let updateOperationType = UpdateOperationType.min([ UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        testUpdateOperations(types: [updateOperationType])
    }
    
    func testUpdateOperationTypeMax() {
        let updateOperationType = UpdateOperationType.max([ UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        testUpdateOperations(types: [updateOperationType])
    }
    
    func testUpdateOperationTypePop() {
        let updateOperationType = UpdateOperationType.pop([ UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        testUpdateOperations(types: [updateOperationType])
    }
    
   
    
    func testUpdateOperationsMultipleTypes() {
        let type1  = UpdateOperationType.set([   UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        let type2  = UpdateOperationType.unset([ UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        let type3  = UpdateOperationType.push([  UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        let type4  = UpdateOperationType.pull([  UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        let type5  = UpdateOperationType.pop([   UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        let type6  = UpdateOperationType.inc([   UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        let type7  = UpdateOperationType.mul([   UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        let type8  = UpdateOperationType.min([   UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        let type9  = UpdateOperationType.max([   UpdateOperationTests.fieldKey : UpdateOperationTests.operationValue ])
        testUpdateOperations(types: [type1, type2, type3, type4, type5, type6, type7, type8, type9])
    }
    
    func testUpdateOperations(types: [UpdateOperationType]) {
        let expectation = self.expectation(description: "update call closure should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let updateOperation = UpdateOperation(criteria: .exists(field: UpdateOperationTests.fieldKey, value: true), mongoDBClient: mongoDBClient)
        
        mongoDBClient.database.collection.expectedInputBlock = { (queryDocument, updateDocument) in
            for type in types {
                let resultDocument = updateDocument[type.key] as! Document
                
                let resultValue = resultDocument[UpdateOperationTests.fieldKey] as! Int
                XCTAssertEqual(resultValue, UpdateOperationTests.operationValue)
            }
            
            let queryExistsDocument = queryDocument[UpdateOperationTests.fieldKey] as? Document
            let queryExistsValue = queryExistsDocument?["$exists"] as! Bool
            XCTAssertEqual(queryExistsValue, true)
            
            expectation.fulfill()
        }
        
        updateOperation.execute(operations: types, collection: mongoDBClient.database.collection)
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testUpdateOperationPullMultiple() {
        let expectation = self.expectation(description: "update call closure should be executed")
        
        let mongoDBClient = TestMongoDBClient()
        
        let updateOperation = UpdateOperation(criteria: .exists(field: UpdateOperationTests.fieldKey, value: true), mongoDBClient: mongoDBClient)
        
        let pullValues = [1, 2]
        let inDocument = Document(key: "$in", value: BsonArray(array: pullValues))
        let type = UpdateOperationType.pull([ UpdateOperationTests.fieldKey : inDocument ])

        mongoDBClient.database.collection.expectedInputBlock = { (queryDocument, updateDocument) in
            let pullDocument = updateDocument[type.key] as! Document
            
            let inDocument = pullDocument[UpdateOperationTests.fieldKey] as? Document
            let pullValuesBson = inDocument?["$in"] as? BsonArray
            let pullValue1 = pullValuesBson?[0] as! Int
            let pullValue2 = pullValuesBson?[1] as! Int
            
            XCTAssertEqual(pullValue1, 1)
            XCTAssertEqual(pullValue2, 2)
            
            let queryExistsDocument = queryDocument[UpdateOperationTests.fieldKey] as? Document
            let queryExistsValue = queryExistsDocument?["$exists"] as! Bool
            XCTAssertEqual(queryExistsValue, true)

            expectation.fulfill()
        }
        
        updateOperation.execute(operations: [type], collection: mongoDBClient.database.collection)
        
        waitForExpectations(timeout: 30, handler: nil)
    }
   
    // MARK: - Classes
    
    class TestCollection: MongoDBService.CollectionType {
        
        var expectedInputBlock: ((_ queryDocument: Document, _ updateDocument: Document) -> ())?
        
        @discardableResult
        func find(query: Document, projection: Document?, limit: Int?) -> StitchTask<[Document]> {
            return StitchTask<[Document]>()
        }
        
        @discardableResult
        func update(query: Document, update: Document?, upsert: Bool, multi: Bool) -> StitchTask<Any> {
            let stitchTask = StitchTask<Any>()
            
            do {
                let resultDoc = try Document(extendedJson: update!.toExtendedJson as! [String : Any])
                stitchTask.result = .success(BsonArray(array: [resultDoc]))
                
                expectedInputBlock?(query, resultDoc)
            }
            catch {
                XCTAssert(false, "Could not create document")
            }
            
            return stitchTask
        }
        
        @discardableResult
        func insert(document: Document) ->  StitchTask<Any> {
            return StitchTask<Any>()
        }
        
        @discardableResult
        func insert(documents: [Document]) ->  StitchTask<Any> {
            return StitchTask<Any>()
        }
        
        @discardableResult
        func delete(query: Document, singleDoc: Bool) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
        
        @discardableResult
        func count(query: Document) -> StitchTask<Int> {
            return StitchTask<Int>()
        }
        
        @discardableResult
        func aggregate(pipeline: [Document]) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
    }
    
    class TestDatabase: DatabaseType {
        
        var client: MongoDBClientType { return TestMongoDBClient() }
        var name: String { return UpdateOperationTests.dbName }
        
        let collection = TestCollection()
        
        @discardableResult
        func collection(named name: String) -> MongoDBService.CollectionType {
            return collection
        }
    }
    
    class TestMongoDBClient: MongoDBClientType {
        
        var stitchClient: StitchClientType { return TestStitchClient() }
        var serviceName: String { return UpdateOperationTests.serviceName }
        
        let database = TestDatabase()
        
        @discardableResult
        func database(named name: String) -> DatabaseType {
            return database
        }
    }
    
    class TestStitchClient: StitchClientType {
        
        var appId: String { return "" }
        var auth: Auth? { return nil }
        var authUser: AuthUser? { return nil }
        var isAuthenticated: Bool { return false }
        var isAnonymous: Bool { return false }
        
        func fetchAuthProviders() -> StitchTask<AuthProviderInfo> {
            return StitchTask<AuthProviderInfo>()
        }
        
        func register(email: String, password: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }
        
        func emailConfirm(token: String, tokenId: String) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
        
        func sendEmailConfirm(toEmail email: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }
        
        func resetPassword(token: String, tokenId: String) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
        
        func sendResetPassword(toEmail email: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }
        
        func anonymousAuth() -> StitchTask<Bool> {
            return StitchTask<Bool>()
        }
        
        func login(withProvider provider: AuthProvider) -> StitchTask<Bool> {
            return StitchTask<Bool>()
        }
        
        func logout() -> StitchTask<Provider?> {
            return StitchTask<Provider?>()
        }
        
        func executePipeline(pipeline: Pipeline) -> StitchTask<Any> {
            return executePipeline(pipelines: [pipeline])
        }
        
        func executePipeline(pipelines: [Pipeline]) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
        
        func addAuthDelegate(delegate: AuthDelegate) {
            
        }        
    }
}
