import XCTest
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

private extension Document {
    func sorted() -> Document {
        return self.sorted { d1, d2 -> Bool in
            d1.key.first! < d2.key.first!
            }.reduce(into: Document()) { (doc, pair) in
                doc[pair.key] = pair.value
        }
    }
}

private extension RemoteMongoCollection {
    func findOne(_ filter: Document) -> Document? {
        let joiner = CallbackJoiner()
        self.find(filter, options: nil).first(joiner.capture())
        return joiner.value()
    }

    func updateOne(filter: Document, update: Document) -> RemoteUpdateResult {
        let joiner = CallbackJoiner()
        self.updateOne(filter: filter, update: update, options: nil, joiner.capture())
        return joiner.value()!
    }

    @discardableResult
    func insertOne(_ document: T) -> RemoteInsertOneResult? {
        let joiner = CallbackJoiner()
        self.insertOne(document, joiner.capture())
        return joiner.value()
    }

    @discardableResult
    func insertMany(_ documents: [T]) -> RemoteInsertManyResult? {
        let joiner = CallbackJoiner()
        self.insertMany(documents, joiner.capture())
        return joiner.value()
    }

    func deleteOne(_ filter: Document) -> RemoteDeleteResult? {
        let joiner = CallbackJoiner()
        self.deleteOne(filter, joiner.capture())
        return joiner.value()
    }
}

private extension Sync {
    func findOne(_ filter: Document) -> Document? {
        let joiner = CallbackJoiner()
        self.find(filter: filter, joiner.capture())
        return joiner.value(asType: MongoCursor<Document>.self)?.next()
    }

    func updateOne(filter: Document, update: Document) -> UpdateResult? {
        let joiner = CallbackJoiner()
        self.updateOne(filter: filter, update: update, options: nil, joiner.capture())
        return joiner.value()
    }

    @discardableResult
    func insertOne(_ document: DocumentT) -> InsertOneResult? {
        let joiner = CallbackJoiner()
        self.insertOne(document: document, joiner.capture())
        return joiner.value()
    }

    func deleteOne(_ filter: Document) -> DeleteResult? {
        let joiner = CallbackJoiner()
        self.deleteOne(filter: filter, joiner.capture())
        return joiner.value()
    }
}

private class StreamJoiner: SSEStreamDelegate {
    var events = [ChangeEvent<Document>]()
    var streamState: SSEStreamState?

    override func on(stateChangedFor state: SSEStreamState) {
        streamState = state
    }

    override func on(newEvent event: RawSSE) {
        guard let changeEvent: ChangeEvent<Document> = try! event.decodeStitchSSE() else {
            return
        }

        events.append(changeEvent)
    }

    func wait(forState state: SSEStreamState) {
        let semaphore = DispatchSemaphore.init(value: 0)
        DispatchWorkItem {
            while self.streamState != state {
                usleep(100)
            }
            semaphore.signal()
        }.perform()
        _ = semaphore.wait(timeout: .init(uptimeNanoseconds: UInt64(1e+10)))
    }

    func wait(forEvents eventCount: Int) {
        let semaphore = DispatchSemaphore.init(value: 0)
        DispatchWorkItem {
            while self.events.count < eventCount {
                usleep(100)
            }
            semaphore.signal()
        }.perform()
        _ = semaphore.wait(timeout: .init(uptimeNanoseconds: UInt64(1e+10)))
    }

    func clearEvents() {
        events.removeAll()
    }
}

private class SyncTestContext {
    let streamJoiner = StreamJoiner()
    let networkMonitor: NetworkMonitor
    let mongoClient: RemoteMongoClient

    lazy var remoteCollAndSync = { () -> (RemoteMongoCollection<Document>, Sync<Document>) in
        let db = mongoClient.db(self.dbName.description)
        XCTAssertEqual(dbName, db.name)
        let coll = db.collection(self.collName)
        XCTAssertEqual(self.dbName, coll.databaseName)
        XCTAssertEqual(self.collName, coll.name)
        let sync = coll.sync
        sync.proxy.dataSynchronizer.isSyncThreadEnabled = false
        sync.proxy.dataSynchronizer.stop()
        return (coll, sync)
    }()

    private let dbName: String
    private let collName: String

    init(mongoClient: RemoteMongoClient,
         networkMonitor: NetworkMonitor,
         dbName: String,
         collName: String) {
        self.mongoClient = mongoClient
        self.networkMonitor = networkMonitor
        self.dbName = dbName
        self.collName = collName
    }

    func streamAndSync() throws {
        let (_, coll) = remoteCollAndSync
        if networkMonitor.state == .connected {
            let iCSDel = coll.proxy
                .dataSynchronizer
                .instanceChangeStreamDelegate

            iCSDel[MongoNamespace(databaseName: dbName, collectionName: collName)]?.add(streamDelegate: streamJoiner)
            if iCSDel[MongoNamespace(databaseName: dbName, collectionName: collName)]?.state == .closed {
                try iCSDel.start()
            }
            streamJoiner.wait(forState: .open)
        }
        _ = try coll.proxy.dataSynchronizer.doSyncPass()
    }

    func watch(forEvents count: Int) throws {
        streamJoiner.wait(forEvents: count)
    }
}

class SyncIntTests: BaseStitchIntTestCocoaTouch {
    private let mongodbUriProp = "test.stitch.mongodbURI"

    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))

    private lazy var mongodbUri: String = pList?[mongodbUriProp] as? String ?? "mongodb://localhost:26000"

    private let dbName = "dbName"
    private let collName = "collName"

    private var mongoClient: RemoteMongoClient!
    private lazy var ctx = SyncTestContext.init(mongoClient: self.mongoClient,
                                                networkMonitor: self.networkMonitor,
                                                dbName: self.dbName,
                                                collName: self.collName)
    
    override func setUp() {
        super.setUp()

        try! prepareService()
        let joiner = CallbackJoiner()
        ctx.remoteCollAndSync.0.deleteMany([:], joiner.capture())
        XCTAssertNotNil(joiner.capturedValue)
        ctx.remoteCollAndSync.1.deleteMany(filter: [:], joiner.capture())
        XCTAssertNotNil(joiner.capturedValue)
        CoreLocalMongoDBService.shared.localInstances.forEach { client in
            try! client.listDatabases().forEach {
                try? client.db($0["name"] as! String).drop()
            }
        }
    }

    override func tearDown() {
        CoreLocalMongoDBService.shared.localInstances.forEach { client in
            try! client.listDatabases().forEach {
                try? client.db($0["name"] as! String).drop()
            }
        }
    }

    override class func tearDown() {
        CoreLocalMongoDBService.shared.close()
    }

    private func prepareService() throws {
        let app = try self.createApp()
        let _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        let svc = try self.addService(
            toApp: app.1,
            withType: "mongodb",
            withName: "mongodb1",
            withConfig: ServiceConfigs.mongodb(
                name: "mongodb1", uri: mongodbUri
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

        self.mongoClient = try client.serviceClient(fromFactory: remoteMongoClientFactory,
                                                    withName: "mongodb1")
    }

    override func goOffline() {
        super.goOffline()
        ctx.streamJoiner.wait(forState: .closed)
    }

    func withoutSyncVersion(_ doc: Document) -> Document {
        return doc.filter { $0.key != documentVersionField }
    }

    func testSync() throws {
        let joiner = CallbackJoiner()
        let (remote, sync) = ctx.remoteCollAndSync

        let doc1: Document = ["hello": "world"]
        var doc2: Document = ["hello": "friend"]
        doc2["proj"] = "field"
        _ = remote.insertMany([doc1, doc2])

        // get the document
        let doc = remote.findOne(doc1)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        // start watching it and always set the value to hello world in a conflict
        sync.configure(conflictHandler: {
            (id: BSONValue, localEvent: ChangeEvent<Document>, remoteEvent: ChangeEvent<Document>) in
            // ensure that there is no version information on the documents in the conflict handler
            XCTAssertNil(localEvent.fullDocument![documentVersionField])
            XCTAssertNil(remoteEvent.fullDocument![documentVersionField])

            if bsonEquals(id, doc1Id) {
                let merged = localEvent.fullDocument!["foo"] as! Int +
                    (remoteEvent.fullDocument!["foo"] as! Int)
                var newDocument = remoteEvent.fullDocument!
                newDocument["foo"] = merged
                return newDocument
            } else {
                return Document(dictionaryLiteral: ("hello", "world"))
            }
        })

        // sync on the remote document
        sync.sync(ids: [doc1Id])
        try ctx.streamAndSync()

        // 1. updating a document remotely should not be reflected until coming back online.
        goOffline()

        let doc1Update = ["$inc": ["foo": 1] as Document] as Document
        // document should successfully update locally.
        // then sync
        XCTAssertEqual(1, remote.updateOne(filter: doc1Filter, update: doc1Update).matchedCount)
        try ctx.streamAndSync()
        // because we are offline, the remote doc should not have updated
        sync.find(filter: ["_id": doc1Id], joiner.capture())
        let found = joiner.value(asType: MongoCursor<Document>.self)!
        XCTAssertEqual(doc, found.next())
        // go back online, and sync
        // the remote document should now equal our expected update
        goOnline()
        try ctx.streamAndSync()
        var expectedDocument = doc
        expectedDocument["foo"] = 1
        sync.find(filter: ["_id": doc1Id], joiner.capture())
        let actualDocument = joiner.value(asType: MongoCursor<Document>.self)?.next()
        XCTAssertEqual(expectedDocument, actualDocument)

        // 2. insertOne should work offline and then sync the document when online.
        goOffline()
        let doc3: Document = ["so": "syncy"]
        sync.insertOne(document: doc3, joiner.capture())
        let insResult = joiner.value(asType: InsertOneResult.self)!
        sync.find(filter: ["_id": insResult.insertedId], joiner.capture())
        var findResult = joiner.value(asType: MongoCursor<Document>.self)!
        XCTAssertEqual(["_id": insResult.insertedId, "so": "syncy"], findResult.next())
        try ctx.streamAndSync()
        remote.find(["_id": doc3["_id"]], options: nil).first(joiner.capture())
        var remoteFindResult: Document? = joiner.value()!
        XCTAssertNil(remoteFindResult)
        goOnline()
        try ctx.streamAndSync()
        remote.find(["_id": insResult.insertedId!], options: nil).first(joiner.capture())
        remoteFindResult = joiner.value()!
        XCTAssertEqual(["_id": insResult.insertedId, "so": "syncy"], withoutSyncVersion(remoteFindResult ?? [:]))

        // 3. updating a document locally that has been updated remotely should invoke the conflict
        // resolver.
        ctx.streamJoiner.clearEvents()
        remote.updateOne(
            filter: doc1Filter,
            update: withNewSyncVersionSet(doc1Update),
            joiner.capture())
        let result2 = joiner.capturedValue as! RemoteUpdateResult
        try ctx.watch(forEvents: 1)
        XCTAssertEqual(1, result2.matchedCount)
        expectedDocument["foo"] = 2
        remote.find(doc1Filter, options: nil).first(joiner.capture())
        remoteFindResult = joiner.value()
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteFindResult!))
        sync.updateOne(
            filter: ["_id": doc1Id],
            update: doc1Update,
            options: nil,
            joiner.capture())
        let result3 = joiner.value(asType: UpdateResult.self)
        XCTAssertEqual(1, result3?.matchedCount)
        expectedDocument["foo"] = 2
        sync.find(filter: ["_id": doc1Id], joiner.capture())
        findResult = joiner.value()!
        XCTAssertEqual(
            expectedDocument,
            findResult.next())
        // first pass will invoke the conflict handler and update locally but not remotely yet
        try ctx.streamAndSync()
        remote.find(doc1Filter, options: nil).first(joiner.capture())
        XCTAssertEqual(expectedDocument, withoutSyncVersion(joiner.value()!))
        expectedDocument["foo"] = 4
        expectedDocument = expectedDocument.filter { $0.key != "fooOps" }
        sync.find(filter: doc1Filter, joiner.capture())
        findResult = joiner.value()!
        XCTAssertEqual(expectedDocument, findResult.next())
        // second pass will update with the ack'd version id
        try ctx.streamAndSync()
        sync.find(filter: doc1Filter, joiner.capture())
        findResult = joiner.value()!
        XCTAssertEqual(expectedDocument, findResult.next())
        remote.find(doc1Filter, options: nil).first(joiner.capture())
        XCTAssertEqual(expectedDocument, withoutSyncVersion(joiner.value()!))
    }

    func testUpdateConflicts() throws {
        let (remote, coll) = ctx.remoteCollAndSync

        let docToInsert: Document = ["hello": "world"]
        remote.insertOne(docToInsert)
        let doc = remote.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter: Document = ["_id": doc1Id]

        coll.configure(conflictHandler: { (_, localEvent: ChangeEvent<Document>, remoteEvent: ChangeEvent<Document>) in
            var merged = localEvent.fullDocument!
            remoteEvent.fullDocument!.forEach { it in
                if (localEvent.fullDocument!.keys.contains(it.key)) {
                    return
                }
                merged[it.key] = it.value
            }
            return merged
        })
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()

        // Update remote
        let remoteUpdate = withNewSyncVersionSet(["$set": ["remote": "update"] as Document])
        let result = remote.updateOne(filter: doc1Filter, update: remoteUpdate)
        try ctx.watch(forEvents: 1)
        XCTAssertEqual(1, result.matchedCount)
        var expectedRemoteDocument = doc
        expectedRemoteDocument["remote"] = "update"
        XCTAssertEqual(expectedRemoteDocument, withoutSyncVersion(remote.findOne(doc1Filter)!))

        // Update local
        let localUpdate = ["$set": ["local": "updateWow"] as Document] as Document
        let localResult = coll.updateOne(filter: doc1Filter, update: localUpdate)
        XCTAssertEqual(1, localResult?.matchedCount)
        XCTAssertEqual(1, localResult?.modifiedCount)
        var expectedLocalDocument = doc
        expectedLocalDocument["local"] = "updateWow"

        XCTAssertEqual(expectedLocalDocument, coll.findOne(doc1Filter))

        // first pass will invoke the conflict handler and update locally but not remotely yet
        try ctx.streamAndSync()

        XCTAssertEqual(expectedRemoteDocument, withoutSyncVersion(remote.findOne(doc1Filter)!))
        expectedLocalDocument["remote"] = "update"


        XCTAssertEqual(expectedLocalDocument, coll.findOne(doc1Filter))

        // second pass will update with the ack'd version id
        try ctx.streamAndSync()

        XCTAssertEqual(expectedLocalDocument, coll.findOne(doc1Filter))
        XCTAssertEqual(expectedLocalDocument.sorted(), withoutSyncVersion(remote.findOne(doc1Filter)!.sorted()))
    }

    func testUpdateRemoteWins() throws {
        let (remote, coll) = ctx.remoteCollAndSync

        // insert a new document remotely
        var docToInsert = ["hello": "world"] as Document
        docToInsert["foo"] = 1
        remote.insertOne(docToInsert)

        // find the document we've just inserted
        let doc = remote.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        // configure Sync to resolve conflicts with remote winning,
        // synchronize the document, and stream events and do a sync pass
        coll.configure(conflictHandler: DefaultConflictHandlers.remoteWins.resolveConflict)

        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()

        // update the document remotely while watching for an update
        var expectedDocument = doc
        let result = remote.updateOne(filter: doc1Filter, update: withNewSyncVersionSet(
            ["$inc": ["foo": 2] as Document]))
        try ctx.watch(forEvents: 1)

        // once the event has been stored,
        // fetch the remote document and assert that it has properly updated
        XCTAssertEqual(1, result.matchedCount)
        expectedDocument["foo"] = 3
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remote.findOne(doc1Filter)!))

        // update the local collection.
        // the count field locally should be 2
        // the count field remotely should be 3
        let localResult = coll.updateOne(filter: doc1Filter, update: ["$inc": ["foo": 1] as Document])
        XCTAssertEqual(1, localResult!.matchedCount)
        expectedDocument["foo"] = 2
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // sync the collection. the remote document should be accepted
        // and this resolution should be reflected locally and remotely
        try ctx.streamAndSync()
        expectedDocument["foo"] = 3
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remote.findOne(doc1Filter)!))
    }

    func testUpdateLocalWins() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a new document remotely
        var docToInsert = ["hello": "world"] as Document
        docToInsert["foo"] = 1
        remoteColl.insertOne(docToInsert)

        // find the document we just inserted
        let doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        // configure Sync to resolve conflicts with local winning,
        // synchronize the document, and stream events and do a sync pass
        coll.configure(conflictHandler: DefaultConflictHandlers.localWins.resolveConflict)
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()

        // update the document remotely while watching for an update
        var expectedDocument = doc
        let result = remoteColl.updateOne(filter: doc1Filter, update: withNewSyncVersionSet(["$inc": ["foo": 2] as Document]))
        try ctx.watch(forEvents: 1)
        // once the event has been stored,
        // fetch the remote document and assert that it has properly updated
        XCTAssertEqual(1, result.matchedCount)
        expectedDocument["foo"] = 3
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))

        // update the local collection.
        // the count field locally should be 2
        // the count field remotely should be 3
        let localResult = coll.updateOne(filter: doc1Filter, update: ["$inc": ["foo": 1] as Document ])
        XCTAssertEqual(1, localResult?.matchedCount)
        expectedDocument["foo"] = 2
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // sync the collection. the local document should be accepted
        // and this resolution should be reflected locally and remotely
        try ctx.streamAndSync()
        expectedDocument["foo"] = 2
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
    }

    func testDeleteOneByIdNoConflict() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a document remotely
        let docToInsert = ["hello": "world"] as Document
        remoteColl.insertOne(docToInsert)

        // find the document we just inserted
        var doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        // configure Sync to fail this test if a conflict occurs.
        // sync on the id, and do a sync pass
        coll.configure(conflictHandler: { (_, _, _) -> Document? in
            fatalError()
        }, changeEventDelegate: nil, errorListener: { (error, _) in
            fatalError(error.localizedDescription)
        })
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()

        // go offline to avoid processing events.
        // delete the document locally
        goOffline()
        let result = coll.deleteOne(doc1Filter)
        XCTAssertEqual(1, result?.deletedCount)

        // assert that, while the remote document remains
        let expectedDocument = withoutSyncVersion(doc)
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertNil(coll.findOne(doc1Filter))

        // go online to begin the syncing process.
        // when syncing, our local delete will be synced to the remote.
        // assert that this is reflected remotely and locally
        goOnline()
        try ctx.streamAndSync()
        XCTAssertNil(remoteColl.findOne(doc1Filter))
        XCTAssertNil(coll.findOne(doc1Filter))
    }

    func testDeleteOneByIdConflict() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a document remotely
        let docToInsert = ["hello": "world"] as Document
        remoteColl.insertOne(docToInsert)

        // find the document we just inserted
        let doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        // configure Sync to resolve a custom document on conflict.
        // sync on the id, and do a sync pass
        coll.configure(conflictHandler: { _, _, _ in
            ["well": "shoot"]
        }, changeEventDelegate: nil, errorListener: { err, _ in fatalError(err.localizedDescription) })
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()

        // update the document remotely
        let doc1Update = ["$inc": ["foo": 1] as Document] as Document
        XCTAssertEqual(1, remoteColl.updateOne(
            filter: doc1Filter,
            update: withNewSyncVersionSet(doc1Update)).matchedCount)

        // go offline, and delete the document locally
        goOffline()
        let result = coll.deleteOne(doc1Filter)
        XCTAssertEqual(1, result?.deletedCount)

        // assert that the remote document has not been deleted,
        // while the local document has been
        var expectedDocument = doc
        expectedDocument["foo"] = 1
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertNil(coll.findOne(doc1Filter))

        // go back online and sync. assert that the remote document has been updated
        // while the local document reflects the resolution of the conflict
        goOnline()
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        expectedDocument = expectedDocument.filter { !($0.key == "hello" || $0.key == "foo") }
        expectedDocument["well"] = "shoot"
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))
    }

    func testInsertThenUpdateThenSync() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // configure Sync to fail this test if there is a conflict.
        // insert and sync the new document locally
        let docToInsert = ["hello": "world"] as Document
        coll.configure(conflictHandler: { (_, _, _) -> Document? in
            XCTFail()
            return nil
        })
        let insertResult = coll.insertOne(docToInsert)!

        // find the local document we just inserted
        let doc = coll.findOne(["_id": insertResult.insertedId])!
        let doc1Id = doc["_id"]
        let doc1Filter = ["_id": doc1Id] as Document

        // update the document locally
        let doc1Update = ["$inc": ["foo": 1] as Document] as Document
        XCTAssertEqual(1, coll.updateOne(filter: doc1Filter, update: doc1Update)?.matchedCount)

        // assert that nothing has been inserting remotely
        var expectedDocument = doc
        expectedDocument["foo"] = 1
        XCTAssertNil(remoteColl.findOne(doc1Filter))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // go online (in case we weren't already). sync.
        goOnline()
        try ctx.streamAndSync()

        // assert that the local insertion reflects remotely
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))
    }

    func testInsertThenSyncUpdateThenUpdate() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // configure Sync to fail this test if there is a conflict.
        // insert and sync the new document locally
        let docToInsert = ["hello": "world"] as Document
        coll.configure(conflictHandler: { _, _, _ in
            XCTFail()
            return nil
        })
        let insertResult = coll.insertOne(docToInsert)!

        // find the document we just inserted
        let doc = coll.findOne(["_id": insertResult.insertedId])!
        let doc1Id = doc["_id"]
        let doc1Filter = ["_id": doc1Id] as Document

        // go online (in case we weren't already). sync.
        // assert that the local insertion reflects remotely
        goOnline()
        try ctx.streamAndSync()
        var expectedDocument = doc
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter)!)

        // update the document locally
        let doc1Update = ["$inc": ["foo": 1] as Document] as Document
        XCTAssertEqual(1, coll.updateOne(filter: doc1Filter, update: doc1Update)?.matchedCount)

        // assert that this update has not been reflected remotely, but has locally
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        expectedDocument["foo"] = 1
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter)!)

        // sync. assert that our update is reflected locally and remotely
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))
    }

    func testInsertThenSyncThenRemoveThenInsertThenUpdate() throws {
        let (remote, coll) = ctx.remoteCollAndSync

        // configure Sync to fail this test if there is a conflict.
        // insert and sync the new document locally. sync.
        let docToInsert: Document = ["hello": "world"]
        coll.configure(conflictHandler: { (_, _, _) -> Document? in
            XCTFail()
            return nil
        })
        let insertResult = coll.insertOne(docToInsert)!
        try ctx.streamAndSync()

        // assert the sync'd document is found locally and remotely
        let doc = coll.findOne(["_id": insertResult.insertedId])!
        let doc1Id = doc["_id"]
        let doc1Filter: Document = ["_id": doc1Id]
        var expectedDocument = doc
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remote.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // delete the doc locally, then re-insert it.
        // assert the document is still the same locally and remotely
        XCTAssertEqual(1, coll.deleteOne(doc1Filter)?.deletedCount)
        coll.insertOne(doc)
        ctx.streamJoiner.wait(forState: .open)  
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remote.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // update the document locally
        let doc1Update = ["$inc": ["foo": 1] as Document] as Document
        XCTAssertEqual(1, coll.updateOne(filter: doc1Filter, update: doc1Update)?.matchedCount)

        // assert that the document has not been updated remotely yet,
        // but has locally
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remote.findOne(doc1Filter)!))
        expectedDocument["foo"] = 1
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // sync. assert that the update has been reflected remotely and locally
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remote.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        goOffline()
    }

    let failingConflictHandler = { (_: BSONValue, _: ChangeEvent<Document>, _: ChangeEvent<Document>) -> Document? in
        fatalError()
    }

    func testRemoteDeletesLocalNoConflict() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a new document remotely
        let docToInsert = ["hello": "world"] as Document
        remoteColl.insertOne(docToInsert)

        // find the document we just inserted
        let doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        // configure Sync with a conflict handler that fails this test
        // in the event of conflict. sync the document, and sync.
        coll.configure(conflictHandler: failingConflictHandler)
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()
        XCTAssertEqual(coll.syncedIds.count, 1)

        // do a remote delete. wait for the event to be stored. sync.
        _ = remoteColl.deleteOne(doc1Filter)
        try ctx.watch(forEvents: 1)

        try ctx.streamAndSync()

        // assert that the remote deletion is reflected locally
        XCTAssertNil(remoteColl.findOne(doc1Filter))
        XCTAssertNil(coll.findOne(doc1Filter))

        // sync. this should not re-sync the document
        try ctx.streamAndSync()

        // insert the document again. sync.
        _ = remoteColl.insertOne(doc)
        try ctx.streamAndSync()

        // assert that the remote insertion is NOT reflected locally
        XCTAssertEqual(doc, remoteColl.findOne(doc1Filter)!)
        XCTAssertNil(coll.findOne(doc1Filter))
    }

    func testRemoteDeletesLocalConflict() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a new document remotely
        let docToInsert = ["hello": "world"] as Document
        remoteColl.insertOne(docToInsert)

        // find the document we just inserted
        let doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        // configure Sync to resolve a custom document on conflict.
        // sync on the id, do a sync pass, and assert that the remote
        // insertion has been reflected locally
        coll.configure(conflictHandler: { _, _, _ in
            ["hello": "world"]
        })
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()
        XCTAssertEqual(doc, coll.findOne(doc1Filter))
        XCTAssertNotNil(coll.findOne(doc1Filter))

        // go offline.
        // delete the document remotely.
        // update the document locally.
        goOffline()
        _ = remoteColl.deleteOne(doc1Filter)
        XCTAssertEqual(1, coll.updateOne(filter: doc1Filter,
                                         update: ["$inc": ["foo": 1] as Document] as Document)?.matchedCount)

        // go back online and sync. assert that the document remains deleted remotely,
        // but has not been reflected locally yet
        goOnline()
        try ctx.streamAndSync()
        XCTAssertNil(remoteColl.findOne(doc1Filter))
        XCTAssertNotNil(coll.findOne(doc1Filter))

        // sync again. assert that the resolution is reflected locally and remotely
        try ctx.streamAndSync()
        XCTAssertNotNil(remoteColl.findOne(doc1Filter))
        XCTAssertNotNil(coll.findOne(doc1Filter))
    }

    func testRemoteInsertsLocalUpdates() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a new document remotely
        let docToInsert = ["hello": "world"] as Document
        remoteColl.insertOne(docToInsert)

        // find the document we just inserted
        let doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        // configure Sync to resolve a custom document on conflict.
        // sync on the id, do a sync pass, and assert that the remote
        // insertion has been reflected locally
        coll.configure(conflictHandler: { _, _, _ in
            ["hello": "again"]
        })
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()
        XCTAssertEqual(doc, coll.findOne(doc1Filter))
        XCTAssertNotNil(coll.findOne(doc1Filter))

        // delete the document remotely, then reinsert it.
        // wait for the events to stream

        _ = remoteColl.deleteOne(doc1Filter)
        _ = remoteColl.insertOne(withNewSyncVersion(doc))
        try ctx.watch(forEvents: 2)

        // update the local document concurrently. sync.
        XCTAssertEqual(1, coll.updateOne(filter: doc1Filter, update: ["$inc": ["foo": 1] as Document])?.matchedCount)
        try ctx.streamAndSync()

        // assert that the remote doc has not reflected the update.
        // assert that the local document has received the resolution
        // from the conflict handled
        XCTAssertEqual(doc, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        var expectedDocument = ["_id": doc1Id] as Document
        expectedDocument["hello"] = "again"
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // do another sync pass. assert that the local and remote docs are in sync
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter)!)
    }

    private func appendDocumentToKey(key: String, on document: Document, documentToAppend: Document) -> Document {
        var document = document
        if var value = document[key] as? Document {
            try! value.merge(documentToAppend)
            document[key] = value
        } else {
            document[key] = documentToAppend
        }

        return document
    }

    private func freshSyncVersionDoc() -> Document {
        return ["spv": 1, "id": UUID.init().uuidString, "v": 0]
    }

    private func withNewSyncVersion(_ document: Document) -> Document {
        var newDocument = document
        newDocument["__stitch_sync_version"] = freshSyncVersionDoc()
        return newDocument
    }

    private func withNewSyncVersionSet(_ document: Document) -> Document {
        return appendDocumentToKey(
            key: "$set",
            on: document,
            documentToAppend: [documentVersionField: freshSyncVersionDoc()])
    }
}