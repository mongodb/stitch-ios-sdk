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

class SyncIntTests: BaseStitchIntTestCocoaTouch {
    private let mongodbUriProp = "test.stitch.mongodbURI"

    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))

    private lazy var mongodbUri: String = pList?[mongodbUriProp] as? String ?? "mongodb://localhost:26000"

    private let dbName = "dbName"
    private let collName = "collName"

    private var mongoClient: RemoteMongoClient!

    override func setUp() {
        super.setUp()

        try! prepareService()
        let joiner = CallbackJoiner()
        remoteCollAndSync().0.deleteMany([:], joiner.capture())
        XCTAssertNotNil(joiner.capturedValue)
        remoteCollAndSync().1.deleteMany(filter: [:], joiner.capture())
        XCTAssertNotNil(joiner.capturedValue)
        CoreLocalMongoDBService.shared.localInstances.forEach { client in
            try! client.listDatabases().forEach {
                try? client.db($0["name"] as! String).drop()
            }
        }
    }

    override func tearDown() {
        let joiner = CallbackJoiner()
        remoteCollAndSync().0.deleteMany([:], joiner.capture())
        XCTAssertNotNil(joiner.capturedValue)
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

    private func remoteCollAndSync() -> (RemoteMongoCollection<Document>, Sync<Document>) {
        let db = mongoClient.db(dbName.description)
        XCTAssertEqual(dbName, db.name)
        let coll = db.collection(collName)
        XCTAssertEqual(dbName, coll.databaseName)
        XCTAssertEqual(collName, coll.name)
        let sync = coll.sync
        sync.proxy.dataSynchronizer.isSyncThreadEnabled = false
        sync.proxy.dataSynchronizer.stop()
        return (coll, sync)
    }

    private func streamAndSync(_ sync: Sync<Document>,
                               streamJoiner: StreamJoiner,
                               waitForEvents eventCount: Int = 0) throws {
        if networkMonitor.state == .connected {
            let iCSDel = sync.proxy
                .dataSynchronizer
                .instanceChangeStreamDelegate

            iCSDel[MongoNamespace(databaseName: dbName, collectionName: collName)]!.add(streamDelegate: streamJoiner)
            if iCSDel[MongoNamespace(databaseName: dbName, collectionName: collName)]?.state == .closed {
                try iCSDel.start()
            }
            streamJoiner.wait(forState: .open)
            streamJoiner.wait(forEvents: eventCount)
        }
        _ = try sync.proxy.dataSynchronizer.doSyncPass()
    }

    private func watch(_ streamJoiner: StreamJoiner, forEvents count: Int) throws {
        streamJoiner.wait(forEvents: count)
    }

    private func stopSync(_ sync: Sync<Document>,
                          streamJoiner: StreamJoiner) {
        goOffline()
        streamJoiner.wait(forState: .closed)
        print("streams closed")
    }

    func withoutSyncVersion(_ doc: Document) -> Document {
        return doc.filter { $0.key != documentVersionField }
    }

    func testSync() throws {
        let streamJoiner = StreamJoiner()
        let joiner = CallbackJoiner()
        let (remote, sync) = remoteCollAndSync()

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
        try streamAndSync(sync, streamJoiner: streamJoiner)

        // 1. updating a document remotely should not be reflected until coming back online.
        stopSync(sync, streamJoiner: streamJoiner)

        let doc1Update = ["$inc": ["foo": 1] as Document] as Document
        // document should successfully update locally.
        // then sync
        XCTAssertEqual(1, remote.updateOne(filter: doc1Filter, update: doc1Update).matchedCount)
        try streamAndSync(sync, streamJoiner: streamJoiner)
        // because we are offline, the remote doc should not have updated
        sync.find(filter: ["_id": doc1Id], joiner.capture())
        let found = joiner.value(asType: MongoCursor<Document>.self)!
        XCTAssertEqual(doc, found.next())
        // go back online, and sync
        // the remote document should now equal our expected update
        goOnline()
        try streamAndSync(sync, streamJoiner: streamJoiner)
        var expectedDocument = doc
        expectedDocument["foo"] = 1
        sync.find(filter: ["_id": doc1Id], joiner.capture())
        let actualDocument = joiner.value(asType: MongoCursor<Document>.self)?.next()
        XCTAssertEqual(expectedDocument, actualDocument)

        // 2. insertOne should work offline and then sync the document when online.
        stopSync(sync, streamJoiner: streamJoiner)
        let doc3: Document = ["so": "syncy"]
        sync.insertOne(document: doc3, joiner.capture())
        let insResult = joiner.value(asType: InsertOneResult.self)!
        sync.find(filter: ["_id": insResult.insertedId], joiner.capture())
        var findResult = joiner.value(asType: MongoCursor<Document>.self)!
        XCTAssertEqual(["_id": insResult.insertedId, "so": "syncy"], findResult.next())
        try streamAndSync(sync, streamJoiner: streamJoiner)
        remote.find(["_id": doc3["_id"]], options: nil).first(joiner.capture())
        var remoteFindResult: Document? = joiner.value()!
        XCTAssertNil(remoteFindResult)
        goOnline()
        try streamAndSync(sync, streamJoiner: streamJoiner)
        remote.find(["_id": insResult.insertedId!], options: nil).first(joiner.capture())
        remoteFindResult = joiner.value()!
        XCTAssertEqual(["_id": insResult.insertedId, "so": "syncy"], withoutSyncVersion(remoteFindResult ?? [:]))

        // 3. updating a document locally that has been updated remotely should invoke the conflict
        // resolver.
        streamJoiner.clearEvents()
        remote.updateOne(
            filter: doc1Filter,
            update: withNewSyncVersionSet(doc1Update),
            joiner.capture())
        let result2 = joiner.capturedValue as! RemoteUpdateResult
        streamJoiner.wait(forEvents: 1)
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
        try streamAndSync(sync, streamJoiner: streamJoiner)
        remote.find(doc1Filter, options: nil).first(joiner.capture())
        XCTAssertEqual(expectedDocument, withoutSyncVersion(joiner.value()!))
        expectedDocument["foo"] = 4
        expectedDocument = expectedDocument.filter { $0.key != "fooOps" }
        sync.find(filter: doc1Filter, joiner.capture())
        findResult = joiner.value()!
        XCTAssertEqual(expectedDocument, findResult.next())
        // second pass will update with the ack'd version id
        try streamAndSync(sync, streamJoiner: streamJoiner)
        sync.find(filter: doc1Filter, joiner.capture())
        findResult = joiner.value()!
        XCTAssertEqual(expectedDocument, findResult.next())
        remote.find(doc1Filter, options: nil).first(joiner.capture())
        XCTAssertEqual(expectedDocument, withoutSyncVersion(joiner.value()!))
    }

    func testUpdateConflicts() throws {
        let streamJoiner = StreamJoiner()

        let (remote, coll) = remoteCollAndSync()

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
        try streamAndSync(coll, streamJoiner: streamJoiner)

        // Update remote
        let remoteUpdate = withNewSyncVersionSet(["$set": ["remote": "update"] as Document])
        let result = remote.updateOne(filter: doc1Filter, update: remoteUpdate)
        try watch(streamJoiner, forEvents: 1)
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
        try streamAndSync(coll, streamJoiner: streamJoiner)

        XCTAssertEqual(expectedRemoteDocument, withoutSyncVersion(remote.findOne(doc1Filter)!))
        expectedLocalDocument["remote"] = "update"


        XCTAssertEqual(expectedLocalDocument, coll.findOne(doc1Filter))

        // second pass will update with the ack'd version id
        try streamAndSync(coll, streamJoiner: streamJoiner)

        XCTAssertEqual(expectedLocalDocument, coll.findOne(doc1Filter))
        XCTAssertEqual(expectedLocalDocument.sorted(), withoutSyncVersion(remote.findOne(doc1Filter)!.sorted()))
    }

    func testUpdateRemoteWins() throws {
        let streamJoiner = StreamJoiner()
        let (remote, coll) = remoteCollAndSync()

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
        try streamAndSync(coll, streamJoiner: streamJoiner)

        // update the document remotely while watching for an update
        var expectedDocument = doc
        let result = remote.updateOne(filter: doc1Filter, update: withNewSyncVersionSet(
            ["$inc": ["foo": 2] as Document]))
        try watch(streamJoiner, forEvents: 1)

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
        try streamAndSync(coll, streamJoiner: streamJoiner)
        expectedDocument["foo"] = 3
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))
        try streamAndSync(coll, streamJoiner: streamJoiner)
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remote.findOne(doc1Filter)!))
    }

    func testUpdateLocalWins() throws {
        let streamJoiner = StreamJoiner()
        let (remoteColl, coll) = remoteCollAndSync()

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
        try streamAndSync(coll, streamJoiner: streamJoiner)

        // update the document remotely while watching for an update
        var expectedDocument = doc
        let result = remoteColl.updateOne(filter: doc1Filter, update: withNewSyncVersionSet(["$inc": ["foo": 2] as Document]))
        try watch(streamJoiner, forEvents: 1)
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
        try streamAndSync(coll, streamJoiner: streamJoiner)
        expectedDocument["foo"] = 2
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))
        try streamAndSync(coll, streamJoiner: streamJoiner)
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
    }

    func testDeleteOneByIdNoConflict() throws {
        let streamJoiner = StreamJoiner()
        let (remoteColl, coll) = remoteCollAndSync()

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
        try streamAndSync(coll, streamJoiner: streamJoiner)

        // go offline to avoid processing events.
        // delete the document locally
        stopSync(coll, streamJoiner: streamJoiner)
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
        try streamAndSync(coll, streamJoiner: streamJoiner)
        XCTAssertNil(remoteColl.findOne(doc1Filter))
        XCTAssertNil(coll.findOne(doc1Filter))
    }

    func testInsertThenSyncThenRemoveThenInsertThenUpdate() throws {
        let streamJoiner = StreamJoiner()

        let (remote, coll) = remoteCollAndSync()

        // configure Sync to fail this test if there is a conflict.
        // insert and sync the new document locally. sync.
        let docToInsert: Document = ["hello": "world"]
        coll.configure(conflictHandler: { (_, _, _) -> Document? in
            XCTFail()
            return nil
        })
        let insertResult = coll.insertOne(docToInsert)!
        try streamAndSync(coll, streamJoiner: streamJoiner)

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
        streamJoiner.wait(forState: .open)
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
        try streamAndSync(coll, streamJoiner: streamJoiner)
        XCTAssertEqual(expectedDocument, withoutSyncVersion(remote.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        stopSync(coll, streamJoiner: streamJoiner)
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

    private func withNewSyncVersionSet(_ document: Document) -> Document {
        return appendDocumentToKey(
            key: "$set",
            on: document,
            documentToAppend: [documentVersionField: freshSyncVersionDoc()])
    }
}
