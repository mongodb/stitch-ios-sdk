// swiftlint:disable type_body_length
// swiftlint:disable function_body_length
// swiftlint:disable file_length
import XCTest
import Foundation
import MongoSwift
@testable import StitchCoreSDK
@testable import StitchCoreRemoteMongoDBService
import StitchCoreSDKMocks

final class CoreRemoteMongoCollectionUnitTests: XCMongoMobileTestCase {
    private let namespace2 = MongoNamespace.init(databaseName: "db2", collectionName: "coll2")

    func testGetName() throws {
        let coll1 = try remoteCollection()
        XCTAssertEqual(namespace.databaseName, coll1.databaseName)
        XCTAssertEqual(namespace.collectionName, coll1.name)

        let coll2 = try remoteCollection(for: namespace2)
        XCTAssertEqual(namespace2.databaseName, coll2.databaseName)
        XCTAssertEqual(namespace2.collectionName, coll2.name)
    }

    func testCollectionType() throws {
        let coll1 = try remoteCollection()
        XCTAssertTrue(Document.self == type(of: coll1).CollectionType.self)

        let coll2 = try remoteCollection(for: namespace2, withType: Int.self)
        XCTAssertTrue(Int.self == type(of: coll2).CollectionType.self)
    }

    func testWithCollectionType() throws {
        let coll1 = try remoteCollection()
        let coll2 = coll1.withCollectionType(Int.self)
        XCTAssertTrue(Int.self == type(of: coll2).CollectionType.self)
    }

    func testCount() throws {
        let coll = try remoteCollection()

        mockServiceClient.callFunctionWithDecodingMock.doReturn(
            result: 42, forArg1: .any, forArg2: .any, forArg3: .any
        )

        // without filter or options
        XCTAssertEqual(42, try coll.count())

        var (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("count", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "query": Document.init()
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // with filter and options
        let expectedFilter: Document = ["one": Int32(23)]
        XCTAssertEqual(42, try coll.count(expectedFilter, options: RemoteCountOptions.init(limit: 5)))

        XCTAssertTrue(mockServiceClient.callFunctionWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!
        XCTAssertEqual("count", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "query": expectedFilter,
            "limit": Int64(5)
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        mockServiceClient.callFunctionWithDecodingMock.doThrow(
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
        let coll = try remoteCollection()

        let doc1: Document = ["one": 2]
        let doc2: Document = ["three": 4]

        let docs = [doc1, doc2]

        mockServiceClient.callFunctionWithDecodingMock.clearStubs()
        mockServiceClient.callFunctionWithDecodingMock.doReturn(
            result: docs, forArg1: .any, forArg2: .any, forArg3: .any
        )

        // without filter or options
        var resultDocs = try coll.find().toArray()

        XCTAssertEqual(docs, resultDocs)

        var (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("find", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
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
        )).toArray()

        XCTAssertEqual(docs, resultDocs)

        XCTAssertTrue(mockServiceClient.callFunctionWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("find", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "query": expectedFilter,
            "project": expectedProject,
            "sort": expectedSort
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        mockServiceClient.callFunctionWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.find().toArray()
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testFindOne() throws {
        let coll = try remoteCollection()

        let doc1: Document = ["hello": "world"]

        mockServiceClient.callFunctionOptionalWithDecodingMock.clearStubs()
        mockServiceClient.callFunctionOptionalWithDecodingMock.doReturn(
            result: doc1, forArg1: .any, forArg2: .any, forArg3: .any
        )

        // Test findOne() without filter or options
        var resultDoc = try coll.findOne()
        XCTAssertNotNil(resultDoc)
        XCTAssertEqual(resultDoc, doc1)

        var (funcNameArg, funcArgsArg, _) =
            mockServiceClient.callFunctionOptionalWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("findOne", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "query": Document.init()
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // test findOne() with filter and options
        let expectedFilter: Document = ["one": Int32(23)]
        let expectedProject: Document = ["two": "four"]
        let expectedSort: Document = ["_id": Int64(-1)]

        resultDoc = try coll.findOne(expectedFilter, options: RemoteFindOptions.init(
            projection: expectedProject,
            sort: expectedSort))
        XCTAssertNotNil(resultDoc)
        XCTAssertEqual(resultDoc, doc1)

        XCTAssertTrue(mockServiceClient.callFunctionOptionalWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) =
            mockServiceClient.callFunctionOptionalWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("findOne", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "query": expectedFilter,
            "project": expectedProject,
            "sort": expectedSort
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // passing nil should be fine
        mockServiceClient.callFunctionOptionalWithDecodingMock.clearStubs()
        mockServiceClient.callFunctionOptionalWithDecodingMock.doReturn(
            result: nil, forArg1: .any, forArg2: .any, forArg3: .any
        )

        resultDoc = try coll.findOne()
        XCTAssertNil(resultDoc)

        // should pass along errors
        mockServiceClient.callFunctionOptionalWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.findOne()
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testAggregate() throws {
        let coll = try remoteCollection()

        let doc1: Document = ["one": 2]
        let doc2: Document = ["three": 4]

        let docs = [doc1, doc2]

        mockServiceClient.callFunctionWithDecodingMock.clearStubs()
        mockServiceClient.callFunctionWithDecodingMock.doReturn(
            result: docs, forArg1: .any, forArg2: .any, forArg3: .any
        )

        // with empty pipeline
        var resultDocs = try coll.aggregate([]).toArray()

        XCTAssertEqual(docs, resultDocs)

        var (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("aggregate", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "pipeline": []
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // with pipeline
        resultDocs = try coll.aggregate([["$match": 1], ["sort": 2]]).toArray()

        let expectedPipeline: [Document] = [
            ["$match": Int32(1)],
            ["sort": Int32(2)]
        ]

        XCTAssertEqual(docs, resultDocs)

        XCTAssertTrue(mockServiceClient.callFunctionWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("aggregate", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "pipeline": expectedPipeline
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        mockServiceClient.callFunctionWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.aggregate([]).toArray()
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testInsertOne() throws {
        let coll = try remoteCollection()

        let id = ObjectId()
        let doc1: Document = ["_id": id, "one": 2]

        mockServiceClient.callFunctionWithDecodingMock.clearStubs()
        mockServiceClient.callFunctionWithDecodingMock.doReturn(
            result: RemoteInsertOneResult.init(insertedId: id),
            forArg1: .any, forArg2: .any, forArg3: .any
        )

        let result = try coll.insertOne(doc1)

        XCTAssertEqual(id, result.insertedId as? ObjectId)
        XCTAssertEqual(id, doc1["_id"] as? ObjectId)

        var (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("insertOne", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        let expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "document": doc1
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // object id should be generated if no _id was provided
        _ = try coll.insertOne(["hello": "world"])
        (_, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!
        XCTAssertNotNil(((funcArgsArg[0] as? Document)!["document"] as? Document)!["_id"] as? ObjectId)

        // should pass along errors
        mockServiceClient.callFunctionWithDecodingMock.doThrow(
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
        let coll = try remoteCollection()

        let id1 = ObjectId()
        let id2 = ObjectId()

        let doc1: Document = ["_id": id1, "one": 2]
        let doc2: Document = ["_id": id2, "three": 4]

        let ids: [Int64: BSONValue] = [Int64(0): id1, Int64(1): id2]

        mockServiceClient.callFunctionWithDecodingMock.doReturn(
            result: RemoteInsertManyResult.init(fromArray: [id1, id2]),
            forArg1: .any, forArg2: .any, forArg3: .any
        )

        let result = try coll.insertMany([doc1, doc2])

        XCTAssertEqual(ids[Int64(0)] as? ObjectId, result.insertedIds[Int64(0)] as? ObjectId)
        XCTAssertEqual(ids[Int64(1)] as? ObjectId, result.insertedIds[Int64(1)] as? ObjectId)

        XCTAssertEqual(result.insertedIds[Int64(0)] as? ObjectId, doc1["_id"] as? ObjectId)
        XCTAssertEqual(result.insertedIds[Int64(1)] as? ObjectId, doc2["_id"] as? ObjectId)

        var (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("insertMany", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        let expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "documents": [doc1, doc2]
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // object ids should be generated if no _id was provided
        _ = try coll.insertMany([["hello": "world"], ["goodbye": "world"]])
        (_, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!
        XCTAssertNotNil(((funcArgsArg[0] as? Document)!["documents"] as? [Document])![0]["_id"] as? ObjectId)
        XCTAssertNotNil(((funcArgsArg[0] as? Document)!["documents"] as? [Document])![1]["_id"] as? ObjectId)

        // should pass along errors
        mockServiceClient.callFunctionWithDecodingMock.doThrow(
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
        let coll = try remoteCollection()

        mockServiceClient.callFunctionWithDecodingMock.doReturn(
            result: RemoteDeleteResult.init(deletedCount: 1),
            forArg1: .any, forArg2: .any, forArg3: .any
        )

        let expectedFilter: Document = ["one": 2]

        let result = try coll.deleteOne(expectedFilter)
        XCTAssertEqual(1, result.deletedCount)

        let (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("deleteOne", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        let expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "query": expectedFilter
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        mockServiceClient.callFunctionWithDecodingMock.doThrow(
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
        let coll = try remoteCollection()

        mockServiceClient.callFunctionWithDecodingMock.doReturn(
            result: RemoteDeleteResult.init(deletedCount: 1),
            forArg1: .any, forArg2: .any, forArg3: .any
        )

        let expectedFilter: Document = ["one": 2]

        let result = try coll.deleteMany(expectedFilter)
        XCTAssertEqual(1, result.deletedCount)

        let (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("deleteMany", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        let expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "query": expectedFilter
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        mockServiceClient.callFunctionWithDecodingMock.doThrow(
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
        let coll = try remoteCollection()

        let id = ObjectId()

        mockServiceClient.callFunctionWithDecodingMock.doReturn(
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

        var (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("updateOne", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
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

        XCTAssertTrue(mockServiceClient.callFunctionWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("updateOne", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "query": expectedFilter,
            "update": expectedUpdate,
            "upsert": true
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        mockServiceClient.callFunctionWithDecodingMock.doThrow(
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
        let coll = try remoteCollection()

        let id = ObjectId()

        mockServiceClient.callFunctionWithDecodingMock.doReturn(
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

        var (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("updateMany", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
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

        XCTAssertTrue(mockServiceClient.callFunctionWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) = mockServiceClient.callFunctionWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("updateMany", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "query": expectedFilter,
            "update": expectedUpdate,
            "upsert": true
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        mockServiceClient.callFunctionWithDecodingMock.doThrow(
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

    func testFindOneAndUpdate() throws {
        let coll = try remoteCollection()

        let doc1: Document = ["hello": "world"]

        mockServiceClient.callFunctionOptionalWithDecodingMock.clearStubs()
        mockServiceClient.callFunctionOptionalWithDecodingMock.doReturn(
            result: doc1, forArg1: .any, forArg2: .any, forArg3: .any
        )

        // Test findOneAndUpdate() without filter or options
        var resultDoc = try coll.findOneAndUpdate(filter: [:], update: [:])
        XCTAssertNotNil(resultDoc)
        XCTAssertEqual(resultDoc, doc1)

        var (funcNameArg, funcArgsArg, _) =
            mockServiceClient.callFunctionOptionalWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("findOneAndUpdate", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "filter": Document.init(),
            "update": Document.init()
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // test findOneAndUpdate() with filter and all options
        let expectedFilter: Document = ["one": Int32(23)]
        let expectedUpdate: Document = ["two": Int32(43)]
        let expectedProject: Document = ["two": "four"]
        let expectedSort: Document = ["_id": Int64(-1)]

        resultDoc = try coll.findOneAndUpdate(
            filter: expectedFilter,
            update: expectedUpdate,
            options: RemoteFindOneAndModifyOptions.init(
                projection: expectedProject,
                sort: expectedSort,
                upsert: true,
                returnNewDocument: true)
        )
        XCTAssertNotNil(resultDoc)
        XCTAssertEqual(resultDoc, doc1)

        XCTAssertTrue(mockServiceClient.callFunctionOptionalWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) =
            mockServiceClient.callFunctionOptionalWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("findOneAndUpdate", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "filter": expectedFilter,
            "update": expectedUpdate,
            "projection": expectedProject,
            "sort": expectedSort,
            "upsert": true,
            "returnNewDocument": true
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // Test findOneAndUpdate to make sure request doesnt send unecessary options
        resultDoc = try coll.findOneAndUpdate(
            filter: expectedFilter,
            update: expectedUpdate,
            options: RemoteFindOneAndModifyOptions.init(
                projection: expectedProject,
                returnNewDocument: false)
        )
        XCTAssertNotNil(resultDoc)
        XCTAssertEqual(resultDoc, doc1)

        XCTAssertTrue(mockServiceClient.callFunctionOptionalWithDecodingMock
            .verify(numberOfInvocations: 3, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) =
            mockServiceClient.callFunctionOptionalWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("findOneAndUpdate", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "filter": expectedFilter,
            "update": expectedUpdate,
            "projection": expectedProject
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // passing nil should be fine
        mockServiceClient.callFunctionOptionalWithDecodingMock.clearStubs()
        mockServiceClient.callFunctionOptionalWithDecodingMock.doReturn(
            result: nil, forArg1: .any, forArg2: .any, forArg3: .any
        )
        resultDoc = try coll.findOneAndUpdate(filter: [:], update: [:])
        XCTAssertNil(resultDoc)

        // should pass along errors
        mockServiceClient.callFunctionOptionalWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.findOneAndUpdate(filter: [:], update: [:])
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testFindOneAndReplace() throws {
        let coll = try remoteCollection()

        let doc1: Document = ["hello": "world"]

        mockServiceClient.callFunctionOptionalWithDecodingMock.clearStubs()
        mockServiceClient.callFunctionOptionalWithDecodingMock.doReturn(
            result: doc1, forArg1: .any, forArg2: .any, forArg3: .any
        )

        // Test findOneAndReplace() without filter or options
        var resultDoc = try coll.findOneAndReplace(filter: [:], replacement: [:])
        XCTAssertNotNil(resultDoc)
        XCTAssertEqual(resultDoc, doc1)

        var (funcNameArg, funcArgsArg, _) =
            mockServiceClient.callFunctionOptionalWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("findOneAndReplace", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "filter": Document.init(),
            "update": Document.init()
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // test findOneAndReplace() with filter and all options
        let expectedFilter: Document = ["one": Int32(23)]
        let expectedUpdate: Document = ["two": Int32(43)]
        let expectedProject: Document = ["two": "four"]
        let expectedSort: Document = ["_id": Int64(-1)]

        resultDoc = try coll.findOneAndReplace(
            filter: expectedFilter,
            replacement: expectedUpdate,
            options: RemoteFindOneAndModifyOptions.init(
                projection: expectedProject,
                sort: expectedSort,
                upsert: true,
                returnNewDocument: true)
        )
        XCTAssertNotNil(resultDoc)
        XCTAssertEqual(resultDoc, doc1)

        XCTAssertTrue(mockServiceClient.callFunctionOptionalWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) =
            mockServiceClient.callFunctionOptionalWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("findOneAndReplace", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "filter": expectedFilter,
            "update": expectedUpdate,
            "projection": expectedProject,
            "sort": expectedSort,
            "upsert": true,
            "returnNewDocument": true
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // Test findOneAndReplace to make sure request doesnt send unecessary options
        resultDoc = try coll.findOneAndReplace(
            filter: expectedFilter,
            replacement: expectedUpdate,
            options: RemoteFindOneAndModifyOptions.init(
                projection: expectedProject,
                returnNewDocument: false)
        )
        XCTAssertNotNil(resultDoc)
        XCTAssertEqual(resultDoc, doc1)

        XCTAssertTrue(mockServiceClient.callFunctionOptionalWithDecodingMock
            .verify(numberOfInvocations: 3, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) =
            mockServiceClient.callFunctionOptionalWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("findOneAndReplace", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "filter": expectedFilter,
            "update": expectedUpdate,
            "projection": expectedProject
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // passing nil should be fine
        mockServiceClient.callFunctionOptionalWithDecodingMock.clearStubs()
        mockServiceClient.callFunctionOptionalWithDecodingMock.doReturn(
            result: nil, forArg1: .any, forArg2: .any, forArg3: .any
        )
        resultDoc = try coll.findOneAndReplace(filter: [:], replacement: [:])
        XCTAssertNil(resultDoc)

        // should pass along errors
        mockServiceClient.callFunctionOptionalWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.findOneAndReplace(filter: [:], replacement: [:])
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testFindOneAndDelete() throws {
        let coll = try remoteCollection()

        let doc1: Document = ["hello": "world"]

        mockServiceClient.callFunctionOptionalWithDecodingMock.clearStubs()
        mockServiceClient.callFunctionOptionalWithDecodingMock.doReturn(
            result: doc1, forArg1: .any, forArg2: .any, forArg3: .any
        )

        // Test findOneAndDelete() without filter or options
        var resultDoc = try coll.findOneAndDelete(filter: [:])
        XCTAssertNotNil(resultDoc)
        XCTAssertEqual(resultDoc, doc1)

        var (funcNameArg, funcArgsArg, _) =
            mockServiceClient.callFunctionOptionalWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("findOneAndDelete", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        var expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "filter": Document.init()
        ]
        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // test findOneAndDelete() with filter and all options
        let expectedFilter: Document = ["one": Int32(23)]
        let expectedProject: Document = ["two": "four"]
        let expectedSort: Document = ["_id": Int64(-1)]

        resultDoc = try coll.findOneAndDelete(
            filter: expectedFilter,
            options: RemoteFindOneAndModifyOptions.init(
                projection: expectedProject,
                sort: expectedSort)
        )
        XCTAssertNotNil(resultDoc)
        XCTAssertEqual(resultDoc, doc1)

        XCTAssertTrue(mockServiceClient.callFunctionOptionalWithDecodingMock
            .verify(numberOfInvocations: 2, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) =
            mockServiceClient.callFunctionOptionalWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("findOneAndDelete", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "filter": expectedFilter,
            "projection": expectedProject,
            "sort": expectedSort
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // Test to make sure request doesnt send unecessary options
        resultDoc = try coll.findOneAndDelete(
            filter: expectedFilter,
            options: RemoteFindOneAndModifyOptions.init(
                projection: expectedProject,
                upsert: true,
                returnNewDocument: true)
        )
        XCTAssertNotNil(resultDoc)
        XCTAssertEqual(resultDoc, doc1)

        XCTAssertTrue(mockServiceClient.callFunctionOptionalWithDecodingMock
            .verify(numberOfInvocations: 3, forArg1: .any, forArg2: .any, forArg3: .any)
        )

        (funcNameArg, funcArgsArg, _) =
            mockServiceClient.callFunctionOptionalWithDecodingMock.capturedInvocations.last!

        XCTAssertEqual("findOneAndDelete", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        expectedArgs = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "filter": expectedFilter,
            "projection": expectedProject
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // passing nil should be fine
        mockServiceClient.callFunctionOptionalWithDecodingMock.clearStubs()
        mockServiceClient.callFunctionOptionalWithDecodingMock.doReturn(
            result: nil, forArg1: .any, forArg2: .any, forArg3: .any
        )
        resultDoc = try coll.findOneAndDelete(filter: [:])
        XCTAssertNil(resultDoc)

        // should pass along errors
        mockServiceClient.callFunctionOptionalWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.findOneAndDelete(filter: [:])
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    class UnitTestWatchDelegate: SSEStreamDelegate { }

    func testWatch() throws {
        let coll = try remoteCollection()

        mockServiceClient.streamFunctionMock.doReturn(
            result: RawSSEStream.init(), forArg1: .any, forArg2: .any, forArg3: .any
        )

        _ = try coll.watch(ids: ["blah"], delegate: UnitTestWatchDelegate.init(), shouldFetchFullDocument: true)

        var (funcNameArg, funcArgsArg, _) = mockServiceClient.streamFunctionMock.capturedInvocations.last!

        XCTAssertEqual("watch", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        let expectedArgs: Document = [
            "database": namespace.databaseName,
            "collection": namespace.collectionName,
            "ids": ["blah"]
        ]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        mockServiceClient.streamFunctionMock.doThrow(
            error: StitchError.serviceError(withMessage: "whoops", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            _ = try coll.watch(ids: ["blahblah"], delegate: UnitTestWatchDelegate.init(), shouldFetchFullDocument: true)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    class MockStream: RawSSEStream {
        override func close() {
            self.delegate?.on(stateChangedFor: .closed)
        }
    }

    class MockDelegate: SSEStreamDelegate {
        let expectation: XCTestExpectation
        init(_ expectation: XCTestExpectation) {
            self.expectation = expectation
        }

        override func on(stateChangedFor state: SSEStreamState) {
            if state == .closed {
                expectation.fulfill()
            }
        }
    }

    private let testUser = CoreStitchUserImpl.init(
        id: "",
        loggedInProviderType: .anonymous,
        loggedInProviderName: "",
        profile: StitchUserProfileImpl.init(userType: "",
                                            identities: [],
                                            data: APIExtendedUserProfileImpl.init()),
        isLoggedIn: true,
        lastAuthActivity: Date().timeIntervalSince1970)

    private func expectStreamToClose(expectation: XCTestExpectation) throws {
        let coll = try remoteCollection()

        mockServiceClient.streamFunctionMock.clearStubs()
        mockServiceClient.streamFunctionMock.doReturn(result: MockStream(),
                                                      forArg1: .any,
                                                      forArg2: .any,
                                                      forArg3: .any)

        let del = MockDelegate.init(expectation)
        let stream = try coll.watch(ids: [], delegate: del, shouldFetchFullDocument: true)
        stream.delegate = del
    }

    func testStreamDoesNotCloseOnLogin() throws {
        let exp = expectation(description: "stream should not close on login")
        exp.isInverted = true
        try expectStreamToClose(expectation: exp)
        coreRemoteMongoClient.onRebindEvent(AuthRebindEvent.userLoggedIn(loggedInUser: testUser))
        wait(for: [exp], timeout: 10)
    }

    func testStreamDoesNotCloseOnLogout() throws {
        let exp = expectation(description: "stream should not close on logout")
        exp.isInverted = true
        try expectStreamToClose(expectation: exp)
        coreRemoteMongoClient.onRebindEvent(AuthRebindEvent.userLoggedOut(loggedOutUser: testUser))
        wait(for: [exp], timeout: 10)
    }

    func testStreamDoesNotCloseOnRemove() throws {
        let exp = expectation(description: "stream should not close on remove")
        exp.isInverted = true
        try expectStreamToClose(expectation: exp)
        coreRemoteMongoClient.dataSynchronizer.waitUntilInitialized()
        coreRemoteMongoClient.onRebindEvent(AuthRebindEvent.userRemoved(removedUser: testUser))
        wait(for: [exp], timeout: 10)
    }

    func testStreamDoesCloseOnSwitch() throws {
        let exp = expectation(description: "stream should close on switch")
        try expectStreamToClose(expectation: exp)
        coreRemoteMongoClient.onRebindEvent(AuthRebindEvent.activeUserChanged(
            currentActiveUser: testUser,
            previousActiveUser: nil))
        wait(for: [exp], timeout: 10)
    }
}
