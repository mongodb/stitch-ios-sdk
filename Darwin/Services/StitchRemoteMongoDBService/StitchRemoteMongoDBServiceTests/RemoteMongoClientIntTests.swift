// swiftlint:disable cyclomatic_complexity
// swiftlint:disable file_length
// swiftlint:disable force_cast
// swiftlint:disable force_try
// swiftlint:disable function_body_length
// swiftlint:disable type_body_length
import XCTest
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

class XCMongoMobileConfiguration: NSObject, XCTestObservation {
    // This init is called first thing as the test bundle starts up and before any test
    // initialization happens
    override init() {
        super.init()
        // We don't need to do any real work, other than register for callbacks
        // when the test suite progresses.
        // XCTestObservation keeps a strong reference to observers
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testBundleWillStart(_ testBundle: Bundle) {
        try? CoreLocalMongoDBService.shared.initialize()
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        CoreLocalMongoDBService.shared.close()
    }
}

class RemoteMongoClientIntTests: BaseStitchIntTestCocoaTouch {

    private let mongodbUriProp = "test.stitch.mongodbURI"

    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))

    private lazy var mongodbUri: String = pList?[mongodbUriProp] as? String ?? "mongodb://localhost:26000"

    private let dbName = ObjectId().hex
    private let collName = ObjectId().hex

    private var mongoClient: RemoteMongoClient!

    override func setUp() {
        super.setUp()

        try! prepareService()
        let joiner = CallbackJoiner()
        getTestColl().deleteMany([:], joiner.capture())
        _ = joiner.capturedValue
    }

    override func tearDown() {
        let joiner = CallbackJoiner()
        getTestColl().deleteMany([:], joiner.capture())
        XCTAssertNotNil(joiner.capturedValue)
        getTestColl().sync.proxy.dataSynchronizer.stop()
        CoreLocalMongoDBService.shared.localInstances.forEach { client in
            try! client.listDatabases().forEach {
                try? client.db($0["name"] as! String).drop()
            }
        }
    }

    private func prepareService() throws {
        let app = try self.createApp()
        _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon)
        let svc = try self.addService(
            toApp: app.1,
            withType: "mongodb",
            withName: "mongodb1",
            withConfig: ServiceConfigs.mongodb(
                name: "mongodb1", uri: mongodbUri
            )
        )

        _ = try self.addRule(
            toService: svc.1,
            withConfig: RuleCreator.mongoDb(
                database: dbName,
                collection: collName,
                roles: [RuleCreator.Role(
                    read: true, write: true
                )],
                schema: RuleCreator.Schema(properties: Document()))
        )

        let client = try self.appClient(forApp: app.0)

        let exp = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _  in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        self.mongoClient = try client.serviceClient(fromFactory: remoteMongoClientFactory,
                                                    withName: "mongodb1")
    }

    private func getTestColl() -> RemoteMongoCollection<Document> {
        let db = mongoClient.db(dbName.description)
        XCTAssertEqual(dbName, db.name)
        let coll = db.collection(collName)
        XCTAssertEqual(dbName, coll.databaseName)
        XCTAssertEqual(collName, coll.name)
        return coll
    }

    private func getTestColl<T>(_ type: T.Type) -> RemoteMongoCollection<T> {
        let db = mongoClient.db(dbName.description)
        XCTAssertEqual(dbName, db.name)
        let coll = db.collection(collName, withCollectionType: type)
        XCTAssertEqual(dbName, coll.databaseName)
        XCTAssertEqual(collName, coll.name)
        return coll
    }

    func testCount() {
        let coll = getTestColl()

        var exp = expectation(description: "should count empty collection")
        coll.count { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(0, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let rawDoc: Document = ["hello": "world"]
        let doc1 = rawDoc
        let doc2 = rawDoc

        exp = expectation(description: "document should be inserted")
        coll.insertOne(doc1) { (_) in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should count collection with one document")
        coll.count { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(1, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "document should be inserted")
        coll.insertOne(doc2) { (_) in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should count collection with two document")
        coll.count { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(2, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find two documents with original document as filter")
        coll.count(rawDoc) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(2, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should not find any documents when filtering for nonexistent document")
        coll.count(["hello": "Friend"]) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(0, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find one document when limiting result")
        coll.count(rawDoc, options: RemoteCountOptions.init(limit: 1)) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(1, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.count(["$who": 1]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    private func withoutId(_ document: Document) -> Document {
        var newDoc = Document()
        document.filter { $0.0 != "_id" }.forEach { (key, value) in
            newDoc[key] = value
        }
        return newDoc
    }

    private func withoutIds(_ documents: [Document]) -> [Document] {
        var list: [Document] = []
        documents.forEach { (doc) in
            list.append(withoutId(doc))
        }
        return list
    }

    func testFindOne() {
        let coll = getTestColl()
        var exp = expectation(description: "should not find any documents in empty collection")

        coll.findOne { result in
            switch result {
            case .success(let doc):
                XCTAssertNil(doc)
            case .failure(let err):
                XCTFail("unexpected failure in findOne \(err)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc1: Document = ["hello": "world"]
        let doc2: Document = ["hello": "friend", "proj": "field"]

        exp = expectation(description: "should insert one document")
        coll.insertOne(doc1) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find the inserted documents")
        coll.findOne { result in
            switch result {
            case .success(let resultDoc):
                XCTAssertNotNil(resultDoc)
                XCTAssertEqual(self.withoutId(doc1), self.withoutId(resultDoc!))
            case .failure(let err):
                XCTFail("unexpected failure in findOne \(err)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should insert one document")
        coll.insertOne(doc2) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find the inserted documents when applying filter")
        coll.findOne(doc2, options: RemoteFindOptions.init(projection: ["proj": 1])) { result in
            switch result {
            case .success(let resultDoc):
                XCTAssertNotNil(resultDoc)
                XCTAssertEqual(["proj": "field"], self.withoutId(resultDoc!))
            case .failure(let err):
                XCTFail("unexpected failure in findOne \(err)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "find with filter should return nil if no documents match")
        coll.findOne(["noAField": 1]) {result in
            switch result {
            case .success(let resultDoc):
                XCTAssertNil(resultDoc)
            case .failure(let err):
                XCTFail("unexpected failure in findOne \(err)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.findOne(["$who": 1]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testFind() {
        let coll = getTestColl()
        var exp = expectation(description: "should not find any documents in empty collection")
        coll.find().toArray { result in
            switch result {
            case .success(let docs):
                XCTAssertEqual([], docs)
            case .failure:
                XCTFail("unexpected failure in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc1: Document = ["hello": "world"]
        let doc2: Document = ["hello": "friend", "proj": "field"]

        exp = expectation(description: "should insert two documents")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find the inserted documents")
        coll.find().toArray { result in
            switch result {
            case .success(let resultDocs):
                XCTAssertEqual(self.withoutId(doc1), self.withoutId(resultDocs[0]))
                XCTAssertEqual(self.withoutId(doc2), self.withoutId(resultDocs[1]))
            case .failure:
                XCTFail("unexpected failure in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find the second document when applying it as a filter")
        coll.find(doc2).first { result in
            switch result {
            case .success(let document):
                XCTAssertEqual(self.withoutId(doc2), self.withoutId(document!))
            case .failure:
                XCTFail("unexpected failure in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should project the result when a projection is specified")
        coll.find(doc2, options: RemoteFindOptions.init(projection: ["proj": 1])).first { result in
            switch result {
            case .success(let document):
                XCTAssertEqual(["proj": "field"], document!)
            case .failure:
                XCTFail("unexpected failure in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "async iterator should work")
        var cursor: RemoteMongoCursor<Document>!

        coll.find().iterator { result in
            switch result {
            case .success(let foundCursor):
                cursor = foundCursor
            case .failure:
                XCTFail("unexpected failure in find")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "iterator should find first document")
        cursor.next({ result in
            switch result {
            case .success(let document):
                XCTAssertEqual(self.withoutId(doc1), self.withoutId(document!))
            case .failure:
                XCTFail("unexpected failure in cursor next")
            }

            exp.fulfill()
        })
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "iterator should find second document")
        cursor.next({ result in
            switch result {
            case .success(let document):
                XCTAssertEqual(self.withoutId(doc2), self.withoutId(document!))
            case .failure:
                XCTFail("unexpected failure in cursor next")
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "iterator should find no more documents")
        cursor.next({ result in
            switch result {
            case .success(let document):
                XCTAssertNil(document)
            case .failure:
                XCTFail("unexpected failure in cursor next")
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.find(["$who": 1]).first { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testAggregate() {
        let coll = getTestColl()
        var exp = expectation(description: "should not find any documents in empty collection")
        coll.aggregate([]).toArray { result in
            switch result {
            case .success(let docs):
                XCTAssertEqual([], docs)
            case .failure:
                XCTFail("unexpected error in aggregate")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc1: Document = ["hello": "world"]
        let doc2: Document = ["hello": "friend"]

        exp = expectation(description: "should insert two documents")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find the inserted documents")
        coll.aggregate([]).toArray { result in
            switch result {
            case .success(let docs):
                XCTAssertEqual(self.withoutId(doc1), self.withoutId(docs[0]))
                XCTAssertEqual(self.withoutId(doc2), self.withoutId(docs[1]))
            case .failure:
                XCTFail("unexpected error in aggregate")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(
            description: "should find the second document when sorting by descending object id, and limiting to 1"
        )
        coll.aggregate([["$sort": ["_id": -1] as Document], ["$limit": 1]]).toArray { result in
            switch result {
            case .success(let docs):
                XCTAssertEqual(1, docs.count)
                XCTAssertEqual(self.withoutId(doc2), self.withoutId(docs.first!))
            case .failure:
                XCTFail("unexpected error in aggregate")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find first document when matching for it")
        coll.aggregate([["$match": doc1]]).toArray { result in
            switch result {
            case .success(let docs):
                XCTAssertEqual(1, docs.count)
                XCTAssertEqual(self.withoutId(doc1), self.withoutId(docs.first!))
            case .failure:
                XCTFail("unexpected error in aggregate")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid pipeline")
        coll.aggregate([["$who": 1]]).first { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testInsertOne() {
        let coll = getTestColl()
        let doc: Document = ["_id": ObjectId(), "hello": "world"]

        var exp = expectation(description: "document should be successfully inserted")
        coll.insertOne(doc) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertEqual(doc["_id"] as! ObjectId, insertResult.insertedId as! ObjectId)
            case .failure:
                XCTFail("unexpected error in insert")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "document should not be inserted again because it would be a duplicate")
        coll.insertOne(doc) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(let message, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                    XCTAssertNotNil(message.range(of: "duplicate"))
                default:
                    XCTFail("unexpected error code")
                }
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "document should be successfully inserted with a differento object ID")
        coll.insertOne(["hello": "world"]) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertNotEqual(doc["_id"] as! ObjectId, insertResult.insertedId as! ObjectId)
            case .failure:
                XCTFail("unexpected error in insert")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testInsertMany() {
        let coll = getTestColl()
        let doc1: Document = ["_id": ObjectId(), "hello": "world"]

        var exp = expectation(description: "single document should be successfully inserted")
        coll.insertMany([doc1]) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertEqual(doc1["_id"] as! ObjectId, insertResult.insertedIds[0] as! ObjectId)
            case .failure:
                XCTFail("unexpected error in insert")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "document should not be inserted again because it would be a duplicate")
        coll.insertMany([doc1]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(let message, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                    XCTAssertNotNil(message.range(of: "duplicate"))
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc2: Document = ["hello": "world"]
        exp = expectation(description: "document should be successfully inserted with a different object ID")
        coll.insertMany([doc2]) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertNotEqual(doc1["_id"] as! ObjectId, insertResult.insertedIds[0] as! ObjectId)
            case .failure:
                XCTFail("unexpected error in insert")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc3: Document = ["one": "two"]
        let doc4: Document = ["three": 4]

        exp = expectation(description: "multiple documents should be successfully inserted")
        coll.insertMany([doc3, doc4]) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertEqual(2, insertResult.insertedIds.count)
            case .failure:
                XCTFail("unexpected error in insert")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "all inserted documents should be findable")
        coll.find().toArray { result in
            switch result {
            case .success(let documents):
                XCTAssertEqual(self.withoutIds([doc1, doc2, doc3, doc4]), self.withoutIds(documents))
            case .failure:
                XCTFail("unexpected error in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testDeleteOne() {
        let coll = getTestColl()

        var exp = expectation(description: "delete on an empty collection should result in no deletions")
        coll.deleteOne([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "delete on an empty collection should result in no deletions")
        coll.deleteOne(["hello": "world"]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc1: Document = ["hello": "world"]
        let doc2: Document = ["hello": "friend"]

        exp = expectation(description: "multiple documents should be inserted")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "deleting in a non-empty collection should work")
        coll.deleteOne([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(1, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "deleting in a non-empty collection should work")
        coll.deleteOne([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(1, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "no more items in collection should result in no deletes")
        coll.deleteOne([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "multiple documents should be inserted")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "deleting an item by filter work")
        coll.deleteOne(doc1) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(1, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(
            description: "once the item is deleted, the delete with the filter should no longer delete anything"
        )
        coll.deleteOne(doc1) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "there should be one document left in the collection")
        coll.count { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(1, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "there should be no documents left matching the filter")
        coll.count(doc1) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(0, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.deleteOne(["$who": 1]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testDeleteMany() {
        let coll = getTestColl()

        var exp = expectation(description: "delete on an empty collection should result in no deletions")
        coll.deleteMany([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "delete on an empty collection should result in no deletions")
        coll.deleteMany(["hello": "world"]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc1: Document = ["hello": "world"]
        let doc2: Document = ["hello": "friend"]

        exp = expectation(description: "multiple documents should be inserted")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "deleting in a non-empty collection should work")
        coll.deleteMany([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(2, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "no more items in collection should result in no deletes")
        coll.deleteMany([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "multiple documents should be inserted")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "deleting an item by filter work")
        coll.deleteMany(doc1) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(1, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(
            description: "once the item is deleted, the delete with the filter should no longer delete anything"
        )
        coll.deleteMany(doc1) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "there should be one document left in the collection")
        coll.count { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(1, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "there should be no documents left matching the filter")
        coll.count(doc1) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(0, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.deleteMany(["$who": 1]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testUpdateOne() {
        let coll = getTestColl()
        let doc1: Document = ["hello": "world"]

        var exp = expectation(description: "updating a document in an empty collection should result in no update")
        coll.updateOne(filter: [:], update: doc1) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(0, updateResult.matchedCount)
                XCTAssertEqual(0, updateResult.modifiedCount)
                XCTAssertNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "upsert should be successful")
        coll.updateOne(filter: [:], update: doc1, options: RemoteUpdateOptions.init(upsert: true)) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(0, updateResult.matchedCount)
                XCTAssertEqual(0, updateResult.modifiedCount)
                XCTAssertNotNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "updating an existing document should work")
        coll.updateOne(filter: [:], update: ["$set": ["woof": "meow"] as Document]) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(1, updateResult.matchedCount)
                XCTAssertEqual(1, updateResult.modifiedCount)
                XCTAssertNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let expectedDoc: Document = ["hello": "world", "woof": "meow"]

        exp = expectation(description: "should find the updated document in the collection")
        coll.find().first { result in
            switch result {
            case .success(let document):
                XCTAssertEqual(expectedDoc, self.withoutId(document!))
            case .failure:
                XCTFail("unexpected error in find")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.updateOne(filter: ["$who": 1], update: [:]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testUpdateMany() {
        let coll = getTestColl()
        let doc1: Document = ["hello": "world"]

        var exp = expectation(description: "updating a document in an empty collection should result in no updates")
        coll.updateMany(filter: [:], update: doc1) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(0, updateResult.matchedCount)
                XCTAssertEqual(0, updateResult.modifiedCount)
                XCTAssertNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "upsert should be successful")
        coll.updateMany(filter: [:], update: doc1, options: RemoteUpdateOptions.init(upsert: true)) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(0, updateResult.matchedCount)
                XCTAssertEqual(0, updateResult.modifiedCount)
                XCTAssertNotNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "updating an existing document should work")
        coll.updateMany(filter: [:], update: ["$set": ["woof": "meow"] as Document]) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(1, updateResult.matchedCount)
                XCTAssertEqual(1, updateResult.modifiedCount)
                XCTAssertNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should insert a document")
        coll.insertOne([:]) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "updating multiple existing documents should work")
        coll.updateMany(filter: [:], update: ["$set": ["woof": "meow"] as Document]) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(2, updateResult.matchedCount)
                XCTAssertEqual(2, updateResult.modifiedCount)
                XCTAssertNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let expectedDoc1: Document = ["hello": "world", "woof": "meow"]
        let expectedDoc2: Document = ["woof": "meow"]

        exp = expectation(description: "should find the updated documents in the collection")
        coll.find().toArray { result in
            switch result {
            case .success(let documents):
                XCTAssertEqual([expectedDoc1, expectedDoc2], self.withoutIds(documents))
            case .failure:
                XCTFail("unexpected error in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.updateMany(filter: ["$who": 1], update: [:]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testFindOneAndUpdate() {
        let coll = getTestColl()
        let joiner = CallbackJoiner()

        // Collection should start out empty
        // This also tests the null return format
        coll.findOneAndUpdate(filter: [:], update: [:], joiner.capture())
        if let resErr = joiner.value(asType: Document.self) {
            XCTFail("Found Document Where It Shouldnt Be \(resErr)")
            return
        }

        // Insert a sample Document
        coll.insertOne(["hello": "world1", "num": 2], joiner.capture())
        _ = joiner.capturedValue

        coll.count([:], joiner.capture())
        XCTAssertEqual(1, joiner.value(asType: Int.self))

        // Sample call to findOneAndUpdate() where we get the previous document back
        coll.findOneAndUpdate(
            filter: ["hello": "world1"],
            update: ["$inc": ["num": 1] as Document, "$set": ["hello": "hellothere"] as Document],
            joiner.capture())
        guard let result1 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world1", "num": 2], withoutId(result1))
        coll.count([:], joiner.capture())
        XCTAssertEqual(1, joiner.value(asType: Int.self))

        // Make sure the update took place
        coll.findOne([:], joiner.capture())
        guard let result2 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "hellothere", "num": 3], withoutId(result2))

        // Call findOneAndUpdate() again but get the new document
        coll.findOneAndUpdate(
            filter: ["hello": "hellothere"],
            update: ["$inc": ["num": 1] as Document],
            options: RemoteFindOneAndModifyOptions(returnNewDocument: true),
            joiner.capture())
        guard let result3 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "hellothere", "num": 4], withoutId(result3))
        coll.count([:], joiner.capture())
        XCTAssertEqual(1, joiner.value(asType: Int.self))

        // Make sure that was the new document
        coll.findOne([:], joiner.capture())
        guard let result4 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "hellothere", "num": 4], withoutId(result4))

        // Test null behaviour again with a filter that should not match any documents
        coll.findOneAndUpdate(filter: ["helloa": "thisisnotreal"], update: ["hi": "there"], joiner.capture())
        if let resErr = joiner.value(asType: Document.self) {
            XCTFail("Found Document Where It Shouldnt Be \(resErr)")
            return
        }

        // Test the upsert option where it should not actually be invoked
        coll.findOneAndUpdate(
            filter: ["hello": "hellothere"],
            update: ["$set": ["hello": "world1", "num": 1] as Document],
            options: RemoteFindOneAndModifyOptions(upsert: true, returnNewDocument: true),
            joiner.capture())
        guard let result5 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world1", "num": 1], withoutId(result5))

        // There should still only be one documnt in the collection
        coll.count([:], joiner.capture())
        XCTAssertEqual(1, joiner.value(asType: Int.self))

        // Test the upsert option where the server should perform upsert and return new document
        coll.findOneAndUpdate(
            filter: ["hello": "hello"],
            update: ["$set": ["hello": "world2", "num": 2] as Document],
            options: RemoteFindOneAndModifyOptions(upsert: true, returnNewDocument: true),
            joiner.capture())
        guard let result6 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world2", "num": 2], withoutId(result6))

        // There should now be 2 documents in the collection
        coll.count([:], joiner.capture())
        XCTAssertEqual(2, joiner.value(asType: Int.self))

        // Test the upsert option where the server should perform upsert and return old document
        // The old document should be empty
        coll.findOneAndUpdate(
            filter: ["hello": "hello"],
            update: ["$set": ["hello": "world3", "num": 3] as Document],
            options: RemoteFindOneAndModifyOptions(upsert: true),
            joiner.capture())
        if let resErr = joiner.value(asType: Document.self) {
            XCTFail("Found Document Where It Shouldnt Be \(resErr)")
            return
        }

        // There should now be three documents in the collection
        coll.count([:], joiner.capture())
        XCTAssertEqual(3, joiner.value(asType: Int.self))

        // Test sort and project
        coll.findOneAndUpdate(
            filter: [:],
            update: ["$inc": ["num": 1] as Document],
            options: RemoteFindOneAndModifyOptions(
                projection: ["hello": 1, "_id": 0],
                sort: ["num": -1]
            ),
            joiner.capture())
        guard let result7 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world3"], result7)

        coll.findOneAndUpdate(
            filter: [:],
            update: ["$inc": ["num": 1] as Document],
            options: RemoteFindOneAndModifyOptions(
                projection: ["hello": 1, "_id": 0],
                sort: ["num": 1]
            ),
            joiner.capture())
        guard let result8 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world1"], result8)

        // Test proper failure
        let exp = expectation(description: "should error with invalid filter")
        coll.findOneAndUpdate(filter: [:], update: ["$who": 1]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testFindOneAndReplace() {
        let coll = getTestColl()
        let joiner = CallbackJoiner()

        // Collection should start out empty
        // This also tests the null return format
        coll.findOneAndReplace(filter: [:], replacement: [:], joiner.capture())
        if let resErr = joiner.value(asType: Document.self) {
            XCTFail("Found Document Where It Shouldnt Be \(resErr)")
            return
        }

        // Insert a sample Document
        coll.insertOne(["hello": "world1", "num": 1], joiner.capture())
        _ = joiner.capturedValue

        coll.count([:], joiner.capture())
        XCTAssertEqual(1, joiner.value(asType: Int.self))

        // Sample call to findOneAndReplace() where we get the previous document back
        coll.findOneAndReplace(
            filter: ["hello": "world1"],
            replacement: ["hello": "world2", "num": 2],
            joiner.capture())
        guard let result1 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world1", "num": 1], withoutId(result1))
        coll.count([:], joiner.capture())
        XCTAssertEqual(1, joiner.value(asType: Int.self))

        // Make sure the update took place
        coll.findOne([:], joiner.capture())
        guard let result2 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world2", "num": 2], withoutId(result2))

        // Call findOneAndReplace() again but get the new document
        coll.findOneAndReplace(
            filter: [:],
            replacement: ["hello": "world3", "num": 3],
            options: RemoteFindOneAndModifyOptions(returnNewDocument: true),
            joiner.capture())
        guard let result3 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world3", "num": 3], withoutId(result3))
        coll.count([:], joiner.capture())
        XCTAssertEqual(1, joiner.value(asType: Int.self))

        // Make sure that was the new document
        coll.findOne([:], joiner.capture())
        guard let result4 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world3", "num": 3], withoutId(result4))

        // Test null behaviour again with a filter that should not match any documents
        coll.findOneAndReplace(filter: ["helloa": "t"], replacement: ["hi": "there"], joiner.capture())
        if let resErr = joiner.value(asType: Document.self) {
            XCTFail("Found Document Where It Shouldnt Be \(resErr)")
            return
        }

        // Test the upsert option where it should not actually be invoked
        coll.findOneAndReplace(
            filter: ["hello": "world3"],
            replacement: ["hello": "world4", "num": 4],
            options: RemoteFindOneAndModifyOptions(upsert: true, returnNewDocument: true),
            joiner.capture())
        guard let result5 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world4", "num": 4], withoutId(result5))

        // There should still only be one documnt in the collection
        coll.count([:], joiner.capture())
        XCTAssertEqual(1, joiner.value(asType: Int.self))

        // Test the upsert option where the server should perform upsert and return new document
        coll.findOneAndReplace(
            filter: ["hello": "world3"],
            replacement: ["hello": "world5", "num": 5],
            options: RemoteFindOneAndModifyOptions(upsert: true, returnNewDocument: true),
            joiner.capture())
        guard let result6 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world5", "num": 5], withoutId(result6))

        // There should now be 2 documents in the collection
        coll.count([:], joiner.capture())
        XCTAssertEqual(2, joiner.value(asType: Int.self))

        // Test the upsert option where the server should perform upsert and return old document
        // The old document should be empty
        coll.findOneAndReplace(
            filter: ["hello": "world3"],
            replacement: ["hello": "world6", "num": 6],
            options: RemoteFindOneAndModifyOptions(upsert: true),
            joiner.capture())
        if let resErr = joiner.value(asType: Document.self) {
            XCTFail("Found Document Where It Shouldnt Be \(resErr)")
            return
        }

        // There should now be three documents in the collection
        coll.count([:], joiner.capture())
        XCTAssertEqual(3, joiner.value(asType: Int.self))

        // Test sort and project
        coll.findOneAndReplace(
            filter: [:],
            replacement: ["hello": "blah", "num": 100],
            options: RemoteFindOneAndModifyOptions(
                projection: ["hello": 1, "_id": 0],
                sort: ["num": -1]
            ),
            joiner.capture())
        guard let result7 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world6"], result7)

        coll.findOneAndReplace(
            filter: [:],
            replacement: ["hello": "blahblah", "num": 200],
            options: RemoteFindOneAndModifyOptions(
                projection: ["hello": 1, "_id": 0],
                sort: ["num": 1]
            ),
            joiner.capture())
        guard let result8 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world4"], result8)

        // Test proper failure
        let exp = expectation(description: "should error with invalid filter")
        coll.findOneAndReplace(filter: [:], replacement: ["$who": 1]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.invalidParameter, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testFindOneAndDelete() {
        let coll = getTestColl()
        let joiner = CallbackJoiner()

        // Collection should start out empty
        // This also tests the null return format
        if case let .success(document) =
            await(coll.findOneAndDelete, [:], nil),
            document != nil {
            XCTFail("Found Document Where It Shouldnt Be: \(String(describing: document))")
            return
        }

        // Insert a sample Document
        guard case .success(let insertOneResult) =
            await(coll.insertOne, ["hello": "world1", "num": 1]) else {
            XCTFail("could not insert sample document")
            return
        }

        guard case .success(1) = await(coll.count, [:], nil) else {
            XCTFail("too many documents in collection")
            return
        }

        // Simple call to findOneAndDelete() where we delete the only document in the collection
        guard case .success(
            ["_id": insertOneResult.insertedId,
             "hello": "world1",
             "num": 1]) = await(coll.findOneAndDelete, [:], nil) else {
            XCTFail("document not found")
            return
        }

        // There should be no documents in the collection
        guard case .success(0) = await(coll.count, [:], nil) else {
            XCTFail("too many documents in collection")
            return
        }

        // TODO: Replace `joiner` with new await syntax
        // Insert a sample Document
        coll.insertOne(["hello": "world1", "num": 1], joiner.capture())
        _ = joiner.capturedValue
        coll.count([:], joiner.capture())
        XCTAssertEqual(1, joiner.value(asType: Int.self))

        // Call findOneAndDelete() again but this time wijth a filter
        coll.findOneAndDelete(
            filter: ["hello": "world1"],
            joiner.capture())
        guard let result2 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world1", "num": 1], withoutId(result2))

        // There should be no documents in the collection
        coll.count([:], joiner.capture())
        XCTAssertEqual(0, joiner.value(asType: Int.self))

        // Insert a sample Document
        coll.insertOne(["hello": "world1", "num": 1], joiner.capture())
        _ = joiner.capturedValue
        coll.count([:], joiner.capture())
        XCTAssertEqual(1, joiner.value(asType: Int.self))

        // Call findOneAndDelete() again but give it filter that does not match any documents
        coll.findOneAndDelete(
            filter: ["hello": "world10"],
            joiner.capture())
        if let resErr = joiner.value(asType: Document.self) {
            XCTFail("Found Document Where It Shouldnt Be \(resErr)")
            return
        }

        // Put in more documents
        let docs: [Document] = [
            ["hello": "world2", "num": 2] as Document,
            ["hello": "world3", "num": 3] as Document
        ]
        coll.insertMany(docs, joiner.capture())
        _ = joiner.capturedValue

        // There should be three doc
        coll.count([:], joiner.capture())
        XCTAssertEqual(3, joiner.value(asType: Int.self))

        // Test project and sort
        coll.findOneAndDelete(
            filter: [:],
            options: RemoteFindOneAndModifyOptions(
                projection: ["hello": 1, "_id": 0],
                sort: ["num": -1]),
            joiner.capture())
        guard let result3 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world3"], withoutId(result3))

        coll.findOneAndDelete(
            filter: [:],
            options: RemoteFindOneAndModifyOptions(
                projection: ["hello": 1, "_id": 0],
                sort: ["num": 1]),
            joiner.capture())
        guard let result4 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual(["hello": "world1"], withoutId(result4))
    }

    class WatchTestDelegate<DocumentT: Codable>: ChangeStreamDelegate {
        public init() {
            self.previousAssertionCalled = true
            self.expectedEventType = .streamOpened
        }

        // swiftlint:disable nesting
        enum EventType {
            case eventReceived
            case errorReceived
            case streamOpened
            case streamClosed
        }
        // swiftlint:enable nesting

        private var expectedEventType: EventType
        private var previousAssertionCalled: Bool

        private var assertion: (() -> Void)?
        private var eventAssertion: ((_ event: ChangeEvent<DocumentT>) -> Void)?

        func expect(eventType: EventType, _ testAssertion: @escaping () -> Void) {
            guard previousAssertionCalled else {
                fatalError("the previous assertion for the expected event was not called")
            }
            self.previousAssertionCalled = false

            self.expectedEventType = eventType
            self.assertion = testAssertion
            self.eventAssertion = nil
        }

        func expectEvent(_ assertion: @escaping (_ event: ChangeEvent<DocumentT>) -> Void) {
            guard previousAssertionCalled else {
                fatalError("the previous assertion for the expected event was not called")
            }
            previousAssertionCalled = false

            self.expectedEventType = .eventReceived
            self.assertion = nil
            self.eventAssertion = assertion
        }

        func didReceive(event: ChangeEvent<DocumentT>) {
            print("got public delegate receieve event")
            switch expectedEventType {
            case .eventReceived:
                guard assertion != nil || eventAssertion != nil else {
                    fatalError("test not configured correctly, must have an assertion when expecting an event")
                }

                if let assertion = assertion {
                    assertion()
                    previousAssertionCalled = true
                } else if let eventAssertion = eventAssertion {
                    eventAssertion(event)
                    previousAssertionCalled = true
                }
            default:
                XCTFail("unexpected receive event, expected to get \(expectedEventType)")
            }
        }

        func didReceive(streamError: Error) {
            print("got public delegate stream error")
            switch expectedEventType {
            case .errorReceived:
                guard let assertion = assertion else {
                    fatalError("test not configured correctly, must have an assertion when expecting an error")
                }

                assertion()
                previousAssertionCalled = true
            default:
                XCTFail("unexpected error event, expected to get \(expectedEventType)")
            }
        }

        func didOpen() {
            print("got public delegate did open")
            switch expectedEventType {
            case .streamOpened:
                guard let assertion = assertion else {
                    fatalError("test not configured correctly, must have an assertion when expecting stream to open")
                }

                assertion()
                previousAssertionCalled = true
            default:
                XCTFail("unexpected stream open event, expected to get \(expectedEventType)")
            }
        }

        func didClose() {
            print("got public delegate did close")
            switch expectedEventType {
            case .streamClosed:
                guard let assertion = assertion else {
                    fatalError("test not configured correctly, must have an assertion when expecting stream to close")
                }

                assertion()
                previousAssertionCalled = true
            default:
                XCTFail("unexpected stream close event, expected to get \(expectedEventType)")
            }
        }
    }

    func testWatch() throws {
        let coll = getTestColl()

        let testDelegate = WatchTestDelegate<Document>.init()
        let doc1: Document = [
            "_id": ObjectId.init(),
            "hello": "universe"
        ]

        // set up CallbackJoiner to make synchronous calls to callback functions
        let joiner = CallbackJoiner()

        // should be notified on stream open
        var exp = expectation(description: "should be notified on stream open")

        testDelegate.expect(eventType: .streamOpened) { exp.fulfill() }
        let stream1 = try coll.watch(ids: [doc1["_id"]!], delegate: testDelegate)
        wait(for: [exp], timeout: 5.0)

        // should receive an event for one document
        exp = expectation(description: "should receive an event for one document")
        testDelegate.expectEvent { event in
            XCTAssertTrue(event.documentKey["_id"]?.bsonEquals(doc1["_id"]) ?? false)
            XCTAssertTrue(doc1.bsonEquals(event.fullDocument))

            XCTAssertEqual(event.operationType, OperationType.insert)
            exp.fulfill()
        }
        coll.insertOne(doc1, joiner.capture())

        wait(for: [exp], timeout: 5.0)

        // should receive more events for a single document
        let updateDoc: Document = [
            "$set": ["hello": "universe"] as Document
        ]
        exp = expectation(description: "should receive more events for a single document")
        testDelegate.expectEvent { event in
            XCTAssertTrue(event.documentKey["_id"]?.bsonEquals(doc1["_id"]) ?? false)
            XCTAssertTrue(doc1.bsonEquals(event.fullDocument))

            XCTAssertEqual(event.operationType, OperationType.update)
            exp.fulfill()
        }
        coll.updateOne(filter: ["_id": doc1["_id"]!], update: updateDoc, joiner.capture())

        wait(for: [exp], timeout: 5.0)

        // should be notified on stream close
        exp = expectation(description: "should be notified on stream close")
        testDelegate.expect(eventType: .streamClosed) { exp.fulfill() }
        stream1.close()
        wait(for: [exp], timeout: 5.0)

        // should receive no more events after stream close
        coll.updateOne(
            filter: ["_id": doc1["_id"]!],
            update: ["$set": ["you": "can't see me"] as Document ] as Document,
            joiner.capture()
        )

        // should receive events for multiple documents being watched
//        let doc2Oid = ObjectId()
        let doc2: Document = [
            "_id": 42,
            "hello": "i am a number doc"
        ]

        let aaaa = ["_id": 42] as Document
        let bbbb = ["_id": Int32(42)] as Document
        let cccc = ["_id": Int64(42)] as Document

        print(aaaa.extendedJSON)
        print(aaaa.canonicalExtendedJSON)

        print(bbbb.extendedJSON)
        print(bbbb.canonicalExtendedJSON)

        print(cccc.extendedJSON)
        print(cccc.canonicalExtendedJSON)

        let doc3: Document = [
            "_id": "blah",
            "hello": "i am a string doc"
        ]

        exp = expectation(description: "notify on stream open")
        testDelegate.expect(eventType: .streamOpened) { exp.fulfill() }
        let stream2 = try coll.watch(ids: [42, "blah"], delegate: testDelegate)
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "doc2 inserted")
        testDelegate.expectEvent { event in
            XCTAssertTrue(event.documentKey["_id"]?.bsonEquals(42) ?? false)
            XCTAssertTrue(event.fullDocument?.bsonEquals(doc2) ?? false)
            XCTAssertEqual(event.operationType, OperationType.insert)
            exp.fulfill()
        }
        coll.insertOne(doc2, joiner.capture())
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "doc3 inserted")
        testDelegate.expectEvent { event in
            XCTAssertTrue(event.documentKey["_id"]?.bsonEquals("blah") ?? false)
            XCTAssertTrue(event.fullDocument?.bsonEquals(doc3) ?? false)
            XCTAssertEqual(event.operationType, OperationType.insert)
            exp.fulfill()
        }
        coll.insertOne(doc3, joiner.capture())
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should be notified on stream close")
        testDelegate.expect(eventType: .streamClosed) { exp.fulfill() }
        stream2.close()
        wait(for: [exp], timeout: 5.0)
    }

    func testWatchWithCustomDocType() throws {
        let coll = getTestColl().withCollectionType(CustomType.self)
        let doc1 = CustomType.init(id: "my_string_id", intValue: 42)

        let testDelegate = WatchTestDelegate<CustomType>.init()
        let joiner = CallbackJoiner.init()

        var exp = expectation(description: "notifies on stream open")
        testDelegate.expect(eventType: .streamOpened) {
            exp.fulfill()
        }

        let stream = try coll.watch(ids: ["my_string_id"], delegate: testDelegate)
        wait(for: [exp], timeout: 5.0)

        // If this code is uncommented, the test should not compile, since you shouldn't be able to use a
        // Document-based test delegate with a CustomType-based collection.
        //
        //        let incorrectlyTypedTestDelegate = WatchTestDelegate<Document>.init()
        //        try coll.watch(ids: ["my_string_id"], delegate: incorrectlyTypedTestDelegate)

        exp = expectation(description: "notifies on document insert")
        testDelegate.expectEvent { event in
            XCTAssertTrue(event.documentKey["_id"]?.bsonEquals(doc1.id) ?? false)
            XCTAssertEqual(event.fullDocument, doc1)
            XCTAssertEqual(event.operationType, OperationType.insert)

            exp.fulfill()
        }
        coll.insertOne(doc1, joiner.capture())
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "notifies on stream close")
        testDelegate.expect(eventType: .streamClosed) {
            exp.fulfill()
        }
        stream.close()
        wait(for: [exp], timeout: 5.0)
    }

    func testWithCollectionType() {
        let coll = getTestColl().withCollectionType(CustomType.self)
        XCTAssertTrue(type(of: coll).CollectionType.self == CustomType.self)

        let expected = CustomType.init(id: "my_string_id", intValue: 42)

        var exp = expectation(description: "type should be able to be inserted")
        coll.insertOne(expected) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertEqual(expected.id, insertResult.insertedId as? String)
            case .failure(let err):
                XCTFail("unexpected error in insert: \(err.localizedDescription)")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should be able to retrieve what was inserted")
        coll.find().first { result in
            switch result {
            case .success(let docResult):
                XCTAssertEqual(expected, docResult!)
            case .failure:
                XCTFail("unexpected error in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testSync_Count() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in }, { _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document
        sync.insertMany(documents: [doc1, doc2], joiner.capture())
        sync.count(joiner.capture())

        XCTAssertEqual(2, joiner.value())

        sync.deleteMany(filter: ["a": "b"], joiner.capture())
        sync.count(joiner.capture())

        XCTAssertEqual(0, joiner.value())
    }

    func testSync_Find() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in }, { _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document
        sync.insertMany(documents: [doc1, doc2], joiner.capture())

        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        sync.find(filter: ["hello": "computer"], options: nil, joiner.capture())
        guard let cursor = joiner.value(asType: MongoCursor<Document>.self),
            let actualDoc = cursor.next() else {
            XCTFail("documents not found")
            return
        }

        XCTAssertEqual("b", actualDoc["a"] as? String)
        XCTAssertNotNil(actualDoc["_id"])
        XCTAssertEqual("computer", actualDoc["hello"] as? String)

        XCTAssertNil(cursor.next())
    }

    func testSync_FindOne() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in }, { _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b"] as Document
        sync.insertMany(documents: [doc1], joiner.capture())

        sync.count(joiner.capture())
        XCTAssertEqual(1, joiner.value())

        sync.findOne(joiner.capture())
        guard let doc = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual("world", doc["hello"] as? String)
        XCTAssertEqual("b", doc["a"] as? String)

        sync.findOne(filter: ["hello": "world"], options: nil, joiner.capture())
        guard let doc2 = joiner.value(asType: Document.self) else {
            XCTFail("document not found")
            return
        }
        XCTAssertEqual("world", doc2["hello"] as? String)
        XCTAssertEqual("b", doc2["a"] as? String)

        sync.findOne(filter: ["hello": "worldsss"], options: nil, joiner.capture())
        let doc3: Document? = joiner.value()
        XCTAssertNil(doc3)
    }

    func testSync_Aggregate() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in }, { _ in })
        let joiner = CallbackJoiner()
        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        sync.insertMany(documents: [doc1, doc2], joiner.capture())
        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        sync.aggregate(
            pipeline: [
                ["$project": ["_id": 0, "a": 0] as Document],
                ["$match": ["hello": "computer"] as Document]
            ],
            options: nil,
            joiner.capture())

        guard let cursor = joiner.value(asType: MongoCursor<Document>.self),
            let actualDoc = cursor.next() else {
                XCTFail("docs not inserted")
                return
        }

        XCTAssertNil(actualDoc["a"])
        XCTAssertNil(actualDoc["_id"])
        XCTAssertEqual("computer", actualDoc["hello"] as? String)

        XCTAssertNil(cursor.next())
    }

    func testSync_InsertOne() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in }, { _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b", documentVersionField: "naughty"] as Document

        sync.insertOne(document: doc1, joiner.capture())
        let insertOneResult = joiner.value(asType: SyncInsertOneResult.self)
        sync.count(joiner.capture())
        XCTAssertEqual(1, joiner.value())
        sync.find(filter: ["_id": insertOneResult?.insertedId ?? BSONNull()], options: nil, joiner.capture())

        guard let cursor = joiner.value(asType: MongoCursor<Document>.self),
            let actualDoc = cursor.next() else {
                XCTFail("doc was not inserted")
                return
        }

        XCTAssertEqual("b", actualDoc["a"] as? String)
        XCTAssert(bsonEquals(insertOneResult?.insertedId ?? nil, actualDoc["_id"]))
        XCTAssertEqual("world", actualDoc["hello"] as? String)
        XCTAssertFalse(actualDoc.hasKey(documentVersionField))
        XCTAssertNil(cursor.next())
    }

    func testSync_InsertMany() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in }, { _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        sync.insertMany(documents: [doc1, doc2], joiner.capture())
        let insertManyResult = joiner.value(asType: SyncInsertManyResult.self)

        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        sync.find(filter: [
            "_id": ["$in": insertManyResult?.insertedIds.values.compactMap { $0 } ?? BSONNull() ] as Document],
                  joiner.capture())
        guard let cursor = joiner.capturedValue as? MongoCursor<Document>,
            let actualDoc = cursor.next() else {
                XCTFail("doc was not inserted")
                return
        }

        XCTAssertEqual("b", actualDoc["a"] as? String)
        XCTAssert(bsonEquals(insertManyResult?.insertedIds[0] ?? nil, actualDoc["_id"]))
        XCTAssertEqual("world", actualDoc["hello"] as? String)
        XCTAssertFalse(actualDoc.hasKey(documentVersionField))
        XCTAssertNotNil(cursor.next())
    }

    func testSync_UpdateOne() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in }, { _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b", documentVersionField: "naughty"] as Document

        sync.updateOne(filter: doc1,
                       update: doc1,
                       options: SyncUpdateOptions(upsert: true),
                       joiner.capture())

        guard let insertedId = (joiner.capturedValue as? SyncUpdateResult)?.upsertedId else {
            XCTFail("doc not upserted")
            return
        }

        sync.updateOne(filter: ["_id": insertedId],
                       update: ["$set": ["hello": "goodbye"] as Document],
                       options: nil,
                       joiner.capture())

        guard let updateResult = joiner.capturedValue as? SyncUpdateResult else {
            XCTFail("failed to update doc")
            return
        }
        XCTAssertEqual(updateResult.matchedCount, 1)
        XCTAssertEqual(updateResult.modifiedCount, 1)
        XCTAssertNil(updateResult.upsertedId)

        sync.count(joiner.capture())
        XCTAssertEqual(1, joiner.value())

        sync.find(filter: ["_id": insertedId],
                  options: nil,
                  joiner.capture())

        guard let cursor = joiner.value(asType: MongoCursor<Document>.self),
            let actualDoc = cursor.next() else {
                XCTFail("doc was not inserted")
                return
        }

        XCTAssertEqual("b", actualDoc["a"] as? String)
        XCTAssertEqual("goodbye", actualDoc["hello"] as? String)
        XCTAssertFalse(actualDoc.hasKey(documentVersionField))
        XCTAssertNil(cursor.next())
    }

    func testSync_UpdateMany() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in }, { _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b", documentVersionField: "naughty"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        sync.insertMany(documents: [doc1, doc2], joiner.capture())

        guard let insertManyResult = (joiner.capturedValue as? SyncInsertManyResult) else {
            XCTFail("insert failed")
            return
        }

        let insertedIds = insertManyResult.insertedIds.compactMap({ $0.value })
        sync.updateMany(filter: ["_id": ["$in": insertedIds] as Document],
                        update: ["$set": ["hello": "goodbye"] as Document],
                        options: nil,
                        joiner.capture())
        guard let updateResult = joiner.capturedValue as? SyncUpdateResult else {
            XCTFail("update failed")
            return
        }

        XCTAssertEqual(updateResult.matchedCount, 2)
        XCTAssertEqual(updateResult.modifiedCount, 2)
        XCTAssertNil(updateResult.upsertedId)

        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        sync.find(filter: ["_id": ["$in": insertedIds] as Document],
                  options: nil,
                  joiner.capture())
        guard let cursor = joiner.value(asType: MongoCursor<Document>.self) else {
            XCTFail("could not find documents")
            return
        }

        cursor.forEach { actualDoc in
            XCTAssertEqual("b", actualDoc["a"] as? String)
            XCTAssertEqual("goodbye", actualDoc["hello"] as? String)
            XCTAssertFalse(actualDoc.hasKey(documentVersionField))
        }
    }

    func testSync_deleteOne() throws {
        let coll = getTestColl()
        let sync = coll.sync

        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in }, { _ in })

        let joiner = CallbackJoiner()

        // ensure that the test collection is empty
        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        // insert some test documents
        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["goodbye": "world", "a": "b"] as Document
        sync.insertMany(documents: [doc1, doc2], joiner.capture())

        // ensure that the documents were inserted
        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        // delete the { hello: "world" } document
        sync.deleteOne(filter: ["hello": "world"], joiner.capture())
        var deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(1, deleteResult?.deletedCount)

        // ensure that there is only one document, and that it is the { goodbye: "world" } one
        sync.count(joiner.capture())
        XCTAssertEqual(1, joiner.value())

        sync.count(filter: ["hello": "world"], options: nil, joiner.capture())
        XCTAssertEqual(0, joiner.value())

        // delete the remaining document with empty filter
        sync.deleteOne(filter: [], joiner.capture())
        deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(1, deleteResult?.deletedCount)

        // collection should be empty
        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        // should not be able to delete any more documents
        sync.deleteOne(filter: [], joiner.capture())
        deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(0, deleteResult?.deletedCount)
    }

    func testSync_deleteMany() throws {
        let coll = getTestColl()
        let sync = coll.sync

        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in }, { _ in })

        let joiner = CallbackJoiner()

        // ensure that the test collection is empty
        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        // insert some test documents
        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["goodbye": "world", "a": "b"] as Document
        sync.insertMany(documents: [doc1, doc2], joiner.capture())

        // ensure that the documents were inserted
        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        // delete documents with a filter for which there are no documents
        sync.deleteMany(filter: ["a": "c"], joiner.capture())
        var deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(0, deleteResult?.deletedCount)

        // ensure nothing got deleted
        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        // delete all the documents we inserted
        sync.deleteMany(filter: ["a": "b"], joiner.capture())
        deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(2, deleteResult?.deletedCount)

        // collection should be empty
        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        // should not be able to delete any more documents
        sync.deleteMany(filter: [], joiner.capture())
        deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(0, deleteResult?.deletedCount)
    }
}

public struct CustomType: Codable {
    public let id: String
    public let intValue: Int

    public enum CodingKeys: String, CodingKey {
        case id = "_id", intValue
    }
}

extension CustomType: Equatable {
    public static func == (lhs: CustomType, rhs: CustomType) -> Bool {
        return lhs.id == rhs.id && lhs.intValue == rhs.intValue
    }
}
