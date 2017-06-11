//
//  MongoDBTests.swift
//  MongoDBTests
//
//  Created by Ofer Meroz on 09/02/2017.
//  Copyright © 2017 Mongo. All rights reserved.
//

import XCTest
@testable import MongoDB
@testable import MongoCore
import MongoExtendedJson


class MongoDBTests: XCTestCase {
    
    static let serviceName = "serviceName"
    static let dbName = "db"
    static let collectionName = "collection"
    
    static let hexString = "1234567890abcdef12345678"
    static let testNumber = 42
    
    
    static var testResultDocument: Document {
        var doc = Document()
        doc["_id"] = try! ObjectId(hexString: MongoDBTests.hexString)
        doc["name"] = "name"
        doc["age"] = testNumber
        return doc
    }
    
    static var response: Any {
        var extendedJsonRepresentableArray: [ExtendedJsonRepresentable] = []
        extendedJsonRepresentableArray.append(MongoDBTests.testResultDocument)
        extendedJsonRepresentableArray.append(MongoDBTests.testResultDocument)
        extendedJsonRepresentableArray.append(MongoDBTests.testResultDocument)
        return BsonArray(array: extendedJsonRepresentableArray)
    }
    
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testFind() {
        let expectation = self.expectation(description: "find call closure should be executed")
        
        MongoClientImpl(stitchClient: TestFindStitchClient(), serviceName: MongoDBTests.serviceName).database(named: MongoDBTests.dbName).collection(named: MongoDBTests.collectionName).find(query: Document(key: "owner_id", value: try! ObjectId(hexString: MongoDBTests.hexString))).response { (result) in
            switch result {
            case .success(let documents):
                XCTAssertEqual(documents.count, (MongoDBTests.response as! BsonArray).count)
                XCTAssertEqual(documents.first!["_id"] as! ObjectId, MongoDBTests.testResultDocument["_id"] as! ObjectId)
                XCTAssertEqual(documents.first!["name"] as! String, MongoDBTests.testResultDocument["name"] as! String)
                XCTAssertEqual(documents.first!["age"] as! NSNumber, MongoDBTests.testResultDocument["age"] as! NSNumber)
                break
            case .failure(let error):
                XCTFail(error.localizedDescription)
                break
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testUpdate() {
        MongoClientImpl(stitchClient: TestUpdateStitchClient(), serviceName: MongoDBTests.serviceName).database(named: MongoDBTests.dbName).collection(named: MongoDBTests.collectionName).update(query: Document(key: "owner_id", value: try! ObjectId(hexString: MongoDBTests.hexString)))
    }
    
    func testInsertSingle() {
        MongoClientImpl(stitchClient: TestInsertStitchClient(), serviceName: MongoDBTests.serviceName).database(named: MongoDBTests.dbName).collection(named: MongoDBTests.collectionName).insert(document: MongoDBTests.testResultDocument)
    }
    
    func testInsertMultiple() {
        MongoClientImpl(stitchClient: TestInsertStitchClient(), serviceName: MongoDBTests.serviceName).database(named: MongoDBTests.dbName).collection(named: MongoDBTests.collectionName).insert(documents: [MongoDBTests.testResultDocument, MongoDBTests.testResultDocument, MongoDBTests.testResultDocument])
    }
    
    func testDeleteSingle() {
        MongoClientImpl(stitchClient: TestDeleteStitchClient(isSingleDelete: true), serviceName: MongoDBTests.serviceName).database(named: MongoDBTests.dbName).collection(named: MongoDBTests.collectionName).delete(query: Document(key: "owner_id", value: try! ObjectId(hexString: MongoDBTests.hexString)))
    }
    
    func testDeleteMultiple() {
        MongoClientImpl(stitchClient: TestDeleteStitchClient(isSingleDelete: false), serviceName: MongoDBTests.serviceName).database(named: MongoDBTests.dbName).collection(named: MongoDBTests.collectionName).delete(query: Document(key: "owner_id", value: try! ObjectId(hexString: MongoDBTests.hexString)), singleDoc: false)
    }
    
    func testAggregate() {
        let queryDocument = Document(key: "owner_id", value: try! ObjectId(hexString: MongoDBTests.hexString))
        let aggregationPipelineDocument = Document(key: "$match", value: queryDocument)

        MongoClientImpl(stitchClient: TestAggregateStitchClient(), serviceName: MongoDBTests.serviceName).database(named: MongoDBTests.dbName).collection(named: MongoDBTests.collectionName).aggregate(pipeline: [aggregationPipelineDocument])
    }
    
    func testCount() {
        let expectation = self.expectation(description: "count call closure should be executed")
        
        MongoClientImpl(stitchClient: TestFindStitchClient(isCountRequest: true), serviceName: MongoDBTests.serviceName).database(named: MongoDBTests.dbName).collection(named: MongoDBTests.collectionName).count(query: Document(key: "owner_id", value: try! ObjectId(hexString: MongoDBTests.hexString))).response { (result) in
            switch result {
            case .success(let number):
                XCTAssertEqual(number, MongoDBTests.testNumber)
                break
            case .failure(let error):
                XCTFail(error.localizedDescription)
                break
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    // MARK: - Helpers
    
    class TestFindStitchClient: BaseTestStitchClient {
        
        private let isCount: Bool
        
        init(isCountRequest: Bool = false) {
            isCount = isCountRequest
        }
        
        @discardableResult
        override func executePipeline(pipeline: Pipeline) -> StitchTask<Any> {
            return executePipeline(pipelines: [pipeline])
        }
        
        @discardableResult
        override func executePipeline(pipelines: [Pipeline]) -> StitchTask<Any> {
            
            var foundFindAction = false
            
            for pipeline in pipelines {
                if pipeline.action == "find" {
                    foundFindAction = true
                    
                    XCTAssertNotNil(pipeline.service)
                    XCTAssertEqual(pipeline.service, serviceName)
                    
                    XCTAssertNotNil(pipeline.args)
                    XCTAssertEqual(pipeline.args?["database"] as! String, dbName)
                    XCTAssertEqual(pipeline.args?["collection"] as! String, collectionName)
                    
                    XCTAssertNotNil(pipeline.args?["query"])
                    XCTAssertEqual((pipeline.args?["query"] as! Document)["owner_id"] as! ObjectId, try ObjectId(hexString: hexString))
                    
                    if isCount {
                        XCTAssertNotNil(pipeline.args?["count"])
                        XCTAssertEqual(pipeline.args?["count"] as! Bool, true)
                    }
                }
                
            }
            
            XCTAssertTrue(foundFindAction, "one of the pipelines must have a `find` action.")
            
            let task = StitchTask<Any>()
            if isCount {
                task.result = .success(BsonArray(array: [testNumber]))
            }
            else {
                task.result = .success(response)
            }
            return task
        }
    }
    
    class TestUpdateStitchClient: BaseTestStitchClient {
        @discardableResult
        override func executePipeline(pipeline: Pipeline) -> StitchTask<Any> {
            return executePipeline(pipelines: [pipeline])
        }
        
        @discardableResult
        override func executePipeline(pipelines: [Pipeline]) -> StitchTask<Any> {
            
            var foundUpdateAction = false
            
            for pipeline in pipelines {
                if pipeline.action == "update" {
                    foundUpdateAction = true
                    
                    XCTAssertNotNil(pipeline.service)
                    XCTAssertEqual(pipeline.service, serviceName)
                    
                    XCTAssertNotNil(pipeline.args)
                    XCTAssertEqual(pipeline.args?["database"] as! String, dbName)
                    XCTAssertEqual(pipeline.args?["collection"] as! String, collectionName)
                    
                    XCTAssertNotNil(pipeline.args?["query"])
                    XCTAssertEqual((pipeline.args?["query"] as! Document)["owner_id"] as! ObjectId, try ObjectId(hexString: hexString))
                    
                    XCTAssertNotNil(pipeline.args?["upsert"])
                    XCTAssertNotNil(pipeline.args?["multi"])
                }
                
            }
            
            XCTAssertTrue(foundUpdateAction, "one of the pipelines must have an `update` action.")
            
            let task = StitchTask<Any>()
            task.result = .success(response)
            return task
        }
    }
    
    class TestInsertStitchClient: BaseTestStitchClient {
        @discardableResult
        override func executePipeline(pipeline: Pipeline) -> StitchTask<Any> {
            return executePipeline(pipelines: [pipeline])
        }
        
        @discardableResult
        override func executePipeline(pipelines: [Pipeline]) -> StitchTask<Any> {
            
            var foundInsertAction = false
            var foundLiteralAction = false
            
            for pipeline in pipelines {
                if pipeline.action == "insert" {
                    foundInsertAction = true
                    
                    XCTAssertNotNil(pipeline.service)
                    XCTAssertEqual(pipeline.service, serviceName)
                    
                    XCTAssertNotNil(pipeline.args)
                    XCTAssertEqual(pipeline.args?["database"] as! String, dbName)
                    XCTAssertEqual(pipeline.args?["collection"] as! String, collectionName)
                }
                
                if pipeline.action == "literal" {
                    foundLiteralAction = true

                    XCTAssertNotNil(pipeline.args)
                    XCTAssertNotNil(pipeline.args?["items"])
                }
            }
            
            XCTAssertTrue(foundInsertAction, "one of the pipelines must have an `insert` action.")
            XCTAssertTrue(foundLiteralAction, "one of the pipelines must have an `literal` action.")
            
            let task = StitchTask<Any>()
            task.result = .success(response)
            return task
        }
    }
    
    class TestDeleteStitchClient: BaseTestStitchClient {
        
        private let isSingle: Bool
        
        init(isSingleDelete: Bool) {
            isSingle = isSingleDelete
        }
        
        @discardableResult
        override func executePipeline(pipeline: Pipeline) -> StitchTask<Any> {
            return executePipeline(pipelines: [pipeline])
        }
        
        @discardableResult
        override func executePipeline(pipelines: [Pipeline]) -> StitchTask<Any> {
            
            var foundDeleteAction = false
            
            for pipeline in pipelines {
                if pipeline.action == "delete" {
                    foundDeleteAction = true
                    
                    XCTAssertNotNil(pipeline.service)
                    XCTAssertEqual(pipeline.service, serviceName)
                    
                    XCTAssertNotNil(pipeline.args)
                    XCTAssertEqual(pipeline.args?["database"] as! String, dbName)
                    XCTAssertEqual(pipeline.args?["collection"] as! String, collectionName)
                    
                    XCTAssertNotNil(pipeline.args?["query"])
                    XCTAssertEqual((pipeline.args?["query"] as! Document)["owner_id"] as! ObjectId, try ObjectId(hexString: hexString))
                    
                    XCTAssertNotNil(pipeline.args?["singleDoc"])
                    XCTAssertEqual(pipeline.args?["singleDoc"] as! Bool, isSingle)
                }
            }
            
            XCTAssertTrue(foundDeleteAction, "one of the pipelines must have an `delete` action.")
            
            let task = StitchTask<Any>()
            task.result = .success(response)
            return task
        }
    }
    
    class TestAggregateStitchClient: BaseTestStitchClient {
        
        @discardableResult
        override func executePipeline(pipeline: Pipeline) -> StitchTask<Any> {
            return executePipeline(pipelines: [pipeline])
        }
        
        @discardableResult
        override func executePipeline(pipelines: [Pipeline]) -> StitchTask<Any> {
            
            var foundAggregateAction = false
            
            for pipeline in pipelines {
                if pipeline.action == "aggregate" {
                    foundAggregateAction = true
                    
                    XCTAssertNotNil(pipeline.service)
                    XCTAssertEqual(pipeline.service, serviceName)
                    
                    XCTAssertNotNil(pipeline.args)
                    XCTAssertEqual(pipeline.args?["database"] as! String, dbName)
                    XCTAssertEqual(pipeline.args?["collection"] as! String, collectionName)
                    
                    XCTAssertNotNil(pipeline.args?["pipeline"])
                    let pipelineBsonArray = pipeline.args?["pipeline"] as? BsonArray
                    let pipelineFirstElement = pipelineBsonArray?[0] as? Document
                    let matchDocument = pipelineFirstElement?["$match"] as? Document
                    let ownerId = matchDocument?["owner_id"] as? ObjectId
                    XCTAssertEqual(ownerId, try ObjectId(hexString: hexString))
                }
            }
            
            XCTAssertTrue(foundAggregateAction, "one of the pipelines must have an `aggregate` action.")
            
            let task = StitchTask<Any>()
            task.result = .success(response)
            return task
        }
    }

    
    class BaseTestStitchClient: StitchClient {
        
        var auth: Auth? { return nil }
        var authUser: AuthUser? { return nil }
        var isAuthenticated: Bool { return false }
        var isAnonymous: Bool { return false }
        
        @discardableResult
        func fetchAuthProviders() -> StitchTask<AuthProviderInfo> {
            return StitchTask<AuthProviderInfo>()
        }
        
        @discardableResult
        func register(email: String, password: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }
        
        @discardableResult
        func emailConfirm(token: String, tokenId: String) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
        
        @discardableResult
        func sendEmailConfirm(toEmail email: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }
        
        @discardableResult
        func resetPassword(token: String, tokenId: String) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
        
        @discardableResult
        func sendResetPassword(toEmail email: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }
        
        @discardableResult
        func anonymousAuth() -> StitchTask<Bool> {
            return StitchTask<Bool>()
        }
        
        @discardableResult
        func login(withProvider provider: AuthProvider) -> StitchTask<Bool> {
            return StitchTask<Bool>()
        }
        
        @discardableResult
        func logout() -> StitchTask<Provider?> {
            return StitchTask<Provider?>()
        }
        
        @discardableResult
        func executePipeline(pipeline: Pipeline) -> StitchTask<Any> {
            return executePipeline(pipelines: [pipeline])
        }
        
        @discardableResult
        func executePipeline(pipelines: [Pipeline]) -> StitchTask<Any> {
            return StitchTask<Any>()
        }
    }
}

