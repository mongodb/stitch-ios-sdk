//
//  MongoDBServiceTests.swift
//  MongoDBServiceTests
//

import XCTest
@testable import MongoDBService
@testable import StitchCore
import ExtendedJson

class MongoDBServiceTests: XCTestCase {

    static let serviceName = "serviceName"
    static let dbName = "db"
    static let collectionName = "collection"

    static let hexString = "1234567890abcdef12345678"
    static let testNumber = Int32(42)

    static var testResultDocument: Document {
        var doc = Document()
        doc["_id"] = try! ObjectId(hexString: MongoDBServiceTests.hexString)
        doc["name"] = "name"
        doc["age"] = testNumber
        return doc
    }

    static var response: BSONCollection {
        var extendedJsonRepresentableArray: [ExtendedJsonRepresentable] = []
        extendedJsonRepresentableArray.append(MongoDBServiceTests.testResultDocument)
        extendedJsonRepresentableArray.append(MongoDBServiceTests.testResultDocument)
        extendedJsonRepresentableArray.append(MongoDBServiceTests.testResultDocument)
        return BSONArray(array: extendedJsonRepresentableArray)
    }

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testFind() throws {
        let expectation = self.expectation(description: "find call closure should be executed")

        MongoDBClient(stitchClient: TestFindStitchClient(),
                      serviceName: MongoDBServiceTests.serviceName)
            .database(named: MongoDBServiceTests.dbName)
            .collection(named: MongoDBServiceTests.collectionName)
            .find(query: try Document(key: "owner_id",
                                          value: try! ObjectId(hexString: MongoDBServiceTests.hexString))).response { (result) in
            switch result.result {
            case .success(let documents):
                XCTAssertEqual(documents.count, (MongoDBServiceTests.response).asArray().count)
                XCTAssertEqual(documents[0]["_id"] as! ObjectId,
                               MongoDBServiceTests.testResultDocument["_id"] as! ObjectId)
                XCTAssertEqual(documents[0]["name"] as! String,
                               MongoDBServiceTests.testResultDocument["name"] as! String)
                XCTAssertEqual(documents[0]["age"] as! NSNumber,
                               MongoDBServiceTests.testResultDocument["age"] as! NSNumber)
                break
            case .failure(let error):
                XCTFail(error.localizedDescription)
                break
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30)
    }

    func testUpdate() throws {
        MongoDBClient(stitchClient: TestUpdateStitchClient(),
                      serviceName: MongoDBServiceTests.serviceName)
            .database(named: MongoDBServiceTests.dbName)
            .collection(named: MongoDBServiceTests.collectionName)
            .updateOne(query: Document(key: "owner_id",
                                           value: try! ObjectId(hexString: MongoDBServiceTests.hexString)),
                       update: Document(key: "owner_id",
                                            value: try! ObjectId(hexString: MongoDBServiceTests.hexString)))
    }

    func testInsertSingle() {
        MongoDBClient(stitchClient: TestInsertStitchClient(),
                      serviceName: MongoDBServiceTests.serviceName)
            .database(named: MongoDBServiceTests.dbName)
            .collection(named: MongoDBServiceTests.collectionName)
            .insertOne(document: MongoDBServiceTests.testResultDocument)
    }

    func testInsertMultiple() {
        MongoDBClient(stitchClient: TestInsertStitchClient(),
                      serviceName: MongoDBServiceTests.serviceName)
            .database(named: MongoDBServiceTests.dbName)
            .collection(named: MongoDBServiceTests.collectionName)
            .insertMany(documents: [MongoDBServiceTests.testResultDocument,
                                    MongoDBServiceTests.testResultDocument,
                                    MongoDBServiceTests.testResultDocument])
    }

    func testDeleteSingle() throws {
        MongoDBClient(stitchClient: TestDeleteStitchClient(isSingleDelete: true),
                      serviceName: MongoDBServiceTests.serviceName)
            .database(named: MongoDBServiceTests.dbName)
            .collection(named: MongoDBServiceTests.collectionName)
            .deleteOne(query: try Document(key: "owner_id", value: try! ObjectId(hexString: MongoDBServiceTests.hexString)))
    }

    func testDeleteMultiple() throws {
        MongoDBClient(stitchClient: TestDeleteStitchClient(isSingleDelete: false),
                      serviceName: MongoDBServiceTests.serviceName)
            .database(named: MongoDBServiceTests.dbName)
            .collection(named: MongoDBServiceTests.collectionName)
            .deleteMany(query: try Document(key: "owner_id", value: try! ObjectId(hexString: MongoDBServiceTests.hexString)))
    }

    func testAggregate() throws {
        let queryDocument = try Document(key: "owner_id",
                                             value: try! ObjectId(hexString: MongoDBServiceTests.hexString))
        let aggregationPipelineDocument = try Document(key: "$match", value: queryDocument)

        MongoDBClient(stitchClient: TestAggregateStitchClient(), serviceName: MongoDBServiceTests.serviceName).database(named: MongoDBServiceTests.dbName).collection(named: MongoDBServiceTests.collectionName).aggregate(pipeline: [aggregationPipelineDocument])
    }

    func testCount() throws {
        let expectation = self.expectation(description: "count call closure should be executed")

        MongoDBClient(stitchClient: TestFindStitchClient(isCountRequest: true),
                      serviceName: MongoDBServiceTests.serviceName)
            .database(named: MongoDBServiceTests.dbName)
            .collection(named: MongoDBServiceTests.collectionName)
            .count(query: Document(key: "owner_id",
                                   value: try! ObjectId(hexString: MongoDBServiceTests.hexString))).response { (result) in
            switch result.result {
            case .success(let number):
                XCTAssertEqual(number, Int(MongoDBServiceTests.testNumber))
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
        override func executePipeline(pipeline: Pipeline) -> StitchTask<BSONCollection> {
            return executePipeline(pipelines: [pipeline])
        }

        @discardableResult
        override func executePipeline(pipelines: [Pipeline]) -> StitchTask<BSONCollection> {

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

            let task = StitchTask<BSONCollection>()
            if isCount {
                task.result = .success(BSONArray(array: [testNumber]))
            } else {
                task.result = .success(response)
            }
            return task
        }
    }

    class TestUpdateStitchClient: BaseTestStitchClient {
        @discardableResult
        override func executePipeline(pipeline: Pipeline) -> StitchTask<BSONCollection> {
            return executePipeline(pipelines: [pipeline])
        }

        @discardableResult
        override func executePipeline(pipelines: [Pipeline]) -> StitchTask<BSONCollection> {

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
                }

            }

            XCTAssertTrue(foundUpdateAction, "one of the pipelines must have an `update` action.")

            let task = StitchTask<BSONCollection>()
            task.result = .success(response)
            return task
        }
    }

    class TestInsertStitchClient: BaseTestStitchClient {
        @discardableResult
        override func executePipeline(pipeline: Pipeline) -> StitchTask<BSONCollection> {
            return executePipeline(pipelines: [pipeline])
        }

        @discardableResult
        override func executePipeline(pipelines: [Pipeline]) -> StitchTask<BSONCollection> {

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

            let task = StitchTask<BSONCollection>()
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
        override func executePipeline(pipeline: Pipeline) -> StitchTask<BSONCollection> {
            return executePipeline(pipelines: [pipeline])
        }

        @discardableResult
        override func executePipeline(pipelines: [Pipeline]) -> StitchTask<BSONCollection> {

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

            let task = StitchTask<BSONCollection>()
            task.result = .success(response)
            return task
        }
    }

    class TestAggregateStitchClient: BaseTestStitchClient {

        @discardableResult
        override func executePipeline(pipeline: Pipeline) -> StitchTask<BSONCollection> {
            return executePipeline(pipelines: [pipeline])
        }

        @discardableResult
        override func executePipeline(pipelines: [Pipeline]) -> StitchTask<BSONCollection> {

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
                    let pipelineBsonArray = pipeline.args?["pipeline"] as? BSONArray
                    let pipelineFirstElement = pipelineBsonArray?[0] as? Document
                    let matchDocument = pipelineFirstElement?["$match"] as? Document
                    let ownerId = matchDocument?["owner_id"] as? ObjectId
                    XCTAssertEqual(ownerId, try ObjectId(hexString: hexString))
                }
            }

            XCTAssertTrue(foundAggregateAction, "one of the pipelines must have an `aggregate` action.")

            let task = StitchTask<BSONCollection>()
            task.result = .success(response)
            return task
        }
    }

    class BaseTestStitchClient: StitchClientType {
        func fetchAuthProviders() -> StitchTask<AuthProviderInfo> {
            return StitchTask<AuthProviderInfo>()
        }

        func register(email: String, password: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }

        func sendEmailConfirm(toEmail email: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }

        func sendResetPassword(toEmail email: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }

        func addAuthDelegate(delegate: AuthDelegate) {

        }

        func emailConfirm(token: String, tokenId: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }

        func resetPassword(token: String, tokenId: String) -> StitchTask<Void> {
            return StitchTask<Void>()
        }

        func anonymousAuth() -> StitchTask<String> {
            return StitchTask<String>()
        }

        func login(withProvider provider: AuthProvider) -> StitchTask<String> {
            return StitchTask<String>()
        }

        func logout() -> StitchTask<Void> {
            return StitchTask<Void>()
        }

        func executePipeline(pipeline: Pipeline) -> StitchTask<BSONCollection> {
            return StitchTask<BSONCollection>()
        }

        func executePipeline(pipelines: [Pipeline]) -> StitchTask<BSONCollection> {
            return StitchTask<BSONCollection>()
        }


        var appId: String { return "" }
        var auth: Auth? { return nil }
        var authUser: UserProfile? { return nil }
        var isAuthenticated: Bool { return false }
        var isAnonymous: Bool { return false }
    }
}
