// swiftlint:disable type_body_length
// swiftlint:disable function_body_length
// swiftlint:disable file_length
import XCTest
import Foundation
import MongoSwift
import StitchCoreSDK
@testable import StitchCoreRemoteMongoDBService
import StitchCoreSDKMocks

final class CoreRemoteMongoCollectionUnitTests: XCTestCase {
    func testGetName() {
        let coll1 = TestUtils.getCollection()
        XCTAssertEqual("dbName1", coll1.databaseName)
        XCTAssertEqual("collName1", coll1.name)

        let coll2 = TestUtils.getCollection(withName: "collName2")
        XCTAssertEqual("dbName1", coll2.databaseName)
        XCTAssertEqual("collName2", coll2.name)
    }

    func testCollectionType() {
        let coll1 = TestUtils.getCollection()
        XCTAssertTrue(Document.self == type(of: coll1).CollectionType.self)

        let coll2 = TestUtils.getDatabase().collection("collName2", withCollectionType: Int.self)
        XCTAssertTrue(Int.self == type(of: coll2).CollectionType.self)
    }

    func testWithCollectionType() {
        let coll1 = TestUtils.getCollection()
        let coll2 = coll1.withCollectionType(Int.self)
        XCTAssertTrue(Int.self == type(of: coll2).CollectionType.self)
    }

    func testCount() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreRemoteMongoClient.init(withService: service)
        let coll = TestUtils.getCollection(withClient: client)

        service.callFunctionWithDecodingMock.doReturn(
            result: 42, forArg1: .any, forArg2: .any, forArg3: .any
        )

        // without filter or options
        XCTAssertEqual(42, try coll.count())

        var (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("count", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": "dbName1",
            "collection": "collName1",
            "query": Document.init()
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // with filter and options
        let expectedFilter: Document = ["one": Int32(23)]
        XCTAssertEqual(42, try coll.count(expectedFilter, options: RemoteCountOptions.init(limit: 5)))

        XCTAssertTrue(service.callFunctionWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("count", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": "dbName1",
            "collection": "collName1",
            "query": expectedFilter,
            "limit": Int64(5)
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        service.callFunctionWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.count()
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testFind() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreRemoteMongoClient.init(withService: service)
        let coll = TestUtils.getCollection(withClient: client)

        let doc1: Document = ["one": 2]
        let doc2: Document = ["three": 4]

        let docs = [doc1, doc2]

        service.callFunctionWithDecodingMock.doReturn(
            result: docs, forArg1: .any, forArg2: .any, forArg3: .any
        )

        // without filter or options
        var resultDocs = try coll.find().asArray()

        XCTAssertEqual(docs, resultDocs)

        var (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("find", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": "dbName1",
            "collection": "collName1",
            "query": Document.init()
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // with filter and options
        let expectedFilter: Document = ["one": Int32(23)]
        let expectedProject: Document = ["two": "four"]
        let expectedSort: Document = ["_id": Int64(-1)]

        resultDocs = try coll.find(expectedFilter, options: RemoteFindOptions.init(
            projection: expectedProject,
            sort: expectedSort
        )).asArray()

        XCTAssertEqual(docs, resultDocs)

        XCTAssertTrue(service.callFunctionWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("find", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": "dbName1",
            "collection": "collName1",
            "query": expectedFilter,
            "project": expectedProject,
            "sort": expectedSort
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        service.callFunctionWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.find().asArray()
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testAggregate() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreRemoteMongoClient.init(withService: service)
        let coll = TestUtils.getCollection(withClient: client)

        let doc1: Document = ["one": 2]
        let doc2: Document = ["three": 4]

        let docs = [doc1, doc2]

        service.callFunctionWithDecodingMock.doReturn(
            result: docs, forArg1: .any, forArg2: .any, forArg3: .any
        )

        // with empty pipeline
        var resultDocs = try coll.aggregate([]).asArray()

        XCTAssertEqual(docs, resultDocs)

        var (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("aggregate", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": "dbName1",
            "collection": "collName1",
            "pipeline": []
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // with pipeline
        resultDocs = try coll.aggregate([["$match": 1], ["sort": 2]]).asArray()

        let expectedPipeline: [Document] = [
            ["$match": Int32(1)],
            ["sort": Int32(2)]
        ]

        XCTAssertEqual(docs, resultDocs)

        XCTAssertTrue(service.callFunctionWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("aggregate", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": "dbName1",
            "collection": "collName1",
            "pipeline": expectedPipeline
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        service.callFunctionWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.aggregate([]).asArray()
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testInsertOne() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreRemoteMongoClient.init(withService: service)
        let coll = TestUtils.getCollection(withClient: client)

        let id = ObjectId()
        let doc1: Document = ["_id": id, "one": 2]

        service.callFunctionWithDecodingMock.doReturn(
            result: RemoteInsertOneResult.init(insertedId: id),
            forArg1: .any, forArg2: .any, forArg3: .any
        )

        let result = try coll.insertOne(doc1)

        XCTAssertEqual(id, result.insertedId as? ObjectId)
        XCTAssertEqual(id, doc1["_id"] as? ObjectId)

        var (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("insertOne", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        let expectedArgs: Document = [
            "database": "dbName1",
            "collection": "collName1",
            "document": doc1
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // object id should be generated if no _id was provided
        _ = try coll.insertOne(["hello": "world"])
        (_, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!
        XCTAssertNotNil(((funcArgsArg[0] as? Document)!["document"] as? Document)!["_id"] as? ObjectId)

        // should pass along errors
        service.callFunctionWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.insertOne(doc1)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testInsertMany() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreRemoteMongoClient.init(withService: service)
        let coll = TestUtils.getCollection(withClient: client)

        let id1 = ObjectId()
        let id2 = ObjectId()

        let doc1: Document = ["_id": id1, "one": 2]
        let doc2: Document = ["_id": id2, "three": 4]

        let ids: [Int64: BSONValue] = [Int64(0): id1, Int64(1): id2]

        service.callFunctionWithDecodingMock.doReturn(
            result: RemoteInsertManyResult.init(fromArray: [id1, id2]),
            forArg1: .any, forArg2: .any, forArg3: .any
        )

        let result = try coll.insertMany([doc1, doc2])

        XCTAssertEqual(ids[Int64(0)] as? ObjectId, result.insertedIds[Int64(0)] as? ObjectId)
        XCTAssertEqual(ids[Int64(1)] as? ObjectId, result.insertedIds[Int64(1)] as? ObjectId)

        XCTAssertEqual(result.insertedIds[Int64(0)] as? ObjectId, doc1["_id"] as? ObjectId)
        XCTAssertEqual(result.insertedIds[Int64(1)] as? ObjectId, doc2["_id"] as? ObjectId)

        var (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("insertMany", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        let expectedArgs: Document = [
            "database": "dbName1",
            "collection": "collName1",
            "documents": [doc1, doc2]
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // object ids should be generated if no _id was provided
        _ = try coll.insertMany([["hello": "world"], ["goodbye": "world"]])
        (_, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!
        XCTAssertNotNil(((funcArgsArg[0] as? Document)!["documents"] as? [Document])![0]["_id"] as? ObjectId)
        XCTAssertNotNil(((funcArgsArg[0] as? Document)!["documents"] as? [Document])![1]["_id"] as? ObjectId)

        // should pass along errors
        service.callFunctionWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.insertMany([doc1, doc2])
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testDeleteOne() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreRemoteMongoClient.init(withService: service)
        let coll = TestUtils.getCollection(withClient: client)

        service.callFunctionWithDecodingMock.doReturn(
            result: RemoteDeleteResult.init(deletedCount: 1),
            forArg1: .any, forArg2: .any, forArg3: .any
        )

        let expectedFilter: Document = ["one": 2]

        let result = try coll.deleteOne(expectedFilter)
        XCTAssertEqual(1, result.deletedCount)

        let (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("deleteOne", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        let expectedArgs: Document = [
            "database": "dbName1",
            "collection": "collName1",
            "query": expectedFilter
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        service.callFunctionWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.deleteOne(expectedFilter)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testDeleteMany() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreRemoteMongoClient.init(withService: service)
        let coll = TestUtils.getCollection(withClient: client)

        service.callFunctionWithDecodingMock.doReturn(
            result: RemoteDeleteResult.init(deletedCount: 1),
            forArg1: .any, forArg2: .any, forArg3: .any
        )

        let expectedFilter: Document = ["one": 2]

        let result = try coll.deleteMany(expectedFilter)
        XCTAssertEqual(1, result.deletedCount)

        let (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("deleteMany", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        let expectedArgs: Document = [
            "database": "dbName1",
            "collection": "collName1",
            "query": expectedFilter
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        service.callFunctionWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.deleteMany(expectedFilter)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testUpdateOne() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreRemoteMongoClient.init(withService: service)
        let coll = TestUtils.getCollection(withClient: client)

        let id = ObjectId()

        service.callFunctionWithDecodingMock.doReturn(
            result: RemoteUpdateResult.init(matchedCount: 1, modifiedCount: 1, upsertedId: id),
            forArg1: .any, forArg2: .any, forArg3: .any
        )

        // without options
        let expectedFilter: Document = ["one": 2]
        let expectedUpdate: Document = ["three": 4]

        var result = try coll.updateOne(filter: expectedFilter, update: expectedUpdate)

        XCTAssertEqual(1, result.matchedCount)
        XCTAssertEqual(1, result.modifiedCount)
        XCTAssertEqual(id, result.upsertedId as? ObjectId)

        var (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("updateOne", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": "dbName1",
            "collection": "collName1",
            "query": expectedFilter,
            "update": expectedUpdate
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // with options
        result = try coll.updateOne(
            filter: expectedFilter,
            update: expectedUpdate,
            options: RemoteUpdateOptions.init(upsert: true)
        )

        XCTAssertEqual(1, result.matchedCount)
        XCTAssertEqual(1, result.modifiedCount)
        XCTAssertEqual(id, result.upsertedId as? ObjectId)

        XCTAssertTrue(service.callFunctionWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("updateOne", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": "dbName1",
            "collection": "collName1",
            "query": expectedFilter,
            "update": expectedUpdate,
            "upsert": true
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        service.callFunctionWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.updateOne(filter: expectedFilter, update: expectedUpdate)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testUpdateMany() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreRemoteMongoClient.init(withService: service)
        let coll = TestUtils.getCollection(withClient: client)

        let id = ObjectId()

        service.callFunctionWithDecodingMock.doReturn(
            result: RemoteUpdateResult.init(matchedCount: 1, modifiedCount: 1, upsertedId: id),
            forArg1: .any, forArg2: .any, forArg3: .any
        )

        // without options
        let expectedFilter: Document = ["one": 2]
        let expectedUpdate: Document = ["three": 4]

        var result = try coll.updateMany(filter: expectedFilter, update: expectedUpdate)

        XCTAssertEqual(1, result.matchedCount)
        XCTAssertEqual(1, result.modifiedCount)
        XCTAssertEqual(id, result.upsertedId as? ObjectId)

        var (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("updateMany", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": "dbName1",
            "collection": "collName1",
            "query": expectedFilter,
            "update": expectedUpdate
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // with options
        result = try coll.updateMany(
            filter: expectedFilter,
            update: expectedUpdate,
            options: RemoteUpdateOptions.init(upsert: true)
        )

        XCTAssertEqual(1, result.matchedCount)
        XCTAssertEqual(1, result.modifiedCount)
        XCTAssertEqual(id, result.upsertedId as? ObjectId)

        XCTAssertTrue(service.callFunctionWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("updateMany", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": "dbName1",
            "collection": "collName1",
            "query": expectedFilter,
            "update": expectedUpdate,
            "upsert": true
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        service.callFunctionWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.updateMany(filter: expectedFilter, update: expectedUpdate)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
}
