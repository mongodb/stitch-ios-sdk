import XCTest
import MongoSwift
import StitchCoreSDK
import StitchCoreAdminClient
import StitchIOSCoreTestUtils
import StitchCoreRemoteMongoDBService
@testable import StitchRemoteMongoDBService

class RemoteMongoClientIntTests: BaseStitchIntTestCocoaTouch {
    
    private let mongodbUriProp = "test.stitch.mongodbURI"
    
    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))
    
    private lazy var mongodbUri: String? = pList?[mongodbUriProp] as? String

    private let dbName = ObjectId().description
    private let collName = ObjectId().description
    
    private var mongoClient: RemoteMongoClient!
    
    override func setUp() {
        guard mongodbUri != nil && mongodbUri != "<your-mongodb-uri>" else {
            XCTFail("No MongoDB URI in properties; failing test. See README for more details.")
            return
        }
        
        super.setUp()
        
        try! prepareService()

    }
    
    private func prepareService() throws {
        let app = try self.createApp()
        let _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        let svc = try self.addService(
            toApp: app.1,
            withType: "mongodb",
            withName: "mongodb1",
            withConfig: ServiceConfigs.mongodb(
                name: "mongodb1", uri: mongodbUri!
            )
        )
        
        let rule: Document = ["read": Document(), "write": Document(), "other_fields": Document()]
        
        _ = try self.addRule(
            toService: svc.1,
            withConfig: RuleCreator.mongoDb(namespace: "\(dbName).\(collName)", rule: rule)
        )
        
        let client = try self.appClient(forApp: app.0)
        
        let exp = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _  in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
        
        self.mongoClient = client.serviceClient(forFactory: RemoteMongoDBService.sharedFactory, withName: "mongodb1")
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
    
    func testFind() {
        let coll = getTestColl()
        var exp = expectation(description: "should not find any documents in empty collection")
        coll.find().asArray { result in
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
        coll.find().asArray { result in
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
        coll.aggregate([]).asArray { result in
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
        coll.aggregate([]).asArray { result in
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
        coll.aggregate([["$sort": Document(["_id": -1])], ["$limit": 1]]).asArray { result in
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
        coll.aggregate([["$match": doc1]]).asArray { result in
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
        coll.find().asArray { result in
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
                XCTAssertNotNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
        
        exp = expectation(description: "updating an existing document should work")
        coll.updateOne(filter: [:], update: ["$set": Document(["woof": "meow"])]) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(1, updateResult.matchedCount)
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
                XCTAssertNotNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
        
        exp = expectation(description: "updating an existing document should work")
        coll.updateMany(filter: [:], update: ["$set": Document(["woof": "meow"])]) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(1, updateResult.matchedCount)
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
        coll.updateMany(filter: [:], update: ["$set": Document(["woof": "meow"])]) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(2, updateResult.matchedCount)
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
        coll.find().asArray { result in
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
    
    func testWithCollectionType() {
        let coll = getTestColl().withCollectionType(CustomType.self)
        XCTAssertTrue(type(of: coll).CollectionType.self == CustomType.self)
        
        let expected = CustomType.init(id: "my_string_id", intValue: 42)
        
        var exp = expectation(description: "type should be able to be inserted")
        coll.insertOne(expected) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertEqual(expected.id, insertResult.insertedId as? String)
            case .failure:
                XCTFail("unexpected error in insert")
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
}

public struct CustomType: Codable {
    public let id: String
    public let intValue: Int
    
    public enum CodingKeys: String, CodingKey {
        case id = "_id", intValue
    }
}

extension CustomType: Equatable {
    static func == (lhs: CustomType, rhs: CustomType) -> Bool {
        return lhs.id == rhs.id && lhs.intValue == rhs.intValue
    }
}
