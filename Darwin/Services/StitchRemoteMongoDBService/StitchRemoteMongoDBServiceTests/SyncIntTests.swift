// swiftlint:disable function_body_length
// swiftlint:disable force_cast
// swiftlint:disable force_try
// swiftlint:disable type_body_length
// swiftlint:disable file_length
import XCTest
@testable import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

private let waitTimeout = UInt64(1e+10)

class SyncIntTests: BaseStitchIntTestCocoaTouch {
    private let mongodbUriProp = "test.stitch.mongodbURI"

    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))

    private lazy var mongodbUri: String = pList?[mongodbUriProp] as? String ?? "mongodb://localhost:26000"

    private let dbName = ObjectId().oid
    private let collName = ObjectId().oid

    private var stitchClient: StitchAppClient!
    private var mongoClient: RemoteMongoClient!
    private lazy var ctx = SyncTestContext.init(stitchClient: self.stitchClient,
                                                mongoClient: self.mongoClient,
                                                networkMonitor: self.networkMonitor,
                                                dbName: self.dbName,
                                                collName: self.collName)

    private var userId1: String!
    private var userId2: String!
    private var userId3: String!

    override func setUp() {
        super.setUp()

        try! prepareService()
        let joiner = CallbackJoiner()
        ctx.remoteCollAndSync.0.deleteMany([:], joiner.capture())
        XCTAssertNotNil(joiner.capturedValue)
        ctx.remoteCollAndSync.1.deleteMany(filter: [:], joiner.capture())
        XCTAssertNotNil(joiner.capturedValue)
    }

    override func tearDown() {
        ctx.teardown()
        CoreLocalMongoDBService.shared.localInstances.forEach { client in
            try! client.listDatabases().forEach {
                try? client.db($0["name"] as! String).drop()
            }
        }
    }

    var mdbService: Apps.App.Services.Service!
    var mdbRule: RuleResponse!

    private func prepareService() throws {
        let app = try self.createApp()
        _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.userpass(
            emailConfirmationURL: "http://emailConfirmURL.com",
            resetPasswordURL: "http://resetPasswordURL.com",
            confirmEmailSubject: "email subject",
            resetPasswordSubject: "reset password subject")
        )
        let svc = try self.addService(
            toApp: app.1,
            withType: "mongodb",
            withName: "mongodb1",
            withConfig: ServiceConfigs.mongodb(
                name: "mongodb1", uri: mongodbUri
            )
        )

        mdbService = svc.1
        let rule = RuleCreator.mongoDb(
            database: dbName,
            collection: collName,
            roles: [RuleCreator.Role(
                read: true, write: true
            )],
            schema: RuleCreator.Schema())
        mdbRule = try self.addRule(
            toService: mdbService,
            withConfig: rule
        )

        let client = try self.appClient(forApp: app.0)

        let joiner = CallbackJoiner()

        client.auth.login(withCredential: AnonymousCredential(), joiner.capture())
        userId3 = joiner.value(asType: StitchUser.self)!.id

        userId2 = try registerAndLoginWithUserPass(
            app: app.1, client: client, email: "test1@10gen.com", pass: "hunter2"
        )
        userId1 = try registerAndLoginWithUserPass(
            app: app.1, client: client, email: "test2@10gen.com", pass: "hunter2"
        )

        self.stitchClient = client
        self.mongoClient = try client.serviceClient(fromFactory: remoteMongoClientFactory,
                                                    withName: "mongodb1")
    }

    override func goOnline() {
        super.goOnline()
    }

    override func goOffline() {
        super.goOffline()
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
        sync.configure(
            conflictHandler: {(id: BSONValue, localEvent: ChangeEvent<Document>, remoteEvent: ChangeEvent<Document>) in
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
        let insResult = joiner.value(asType: SyncInsertOneResult.self)!
        sync.find(filter: ["_id": insResult.insertedId ?? BSONNull()], joiner.capture())
        var findResult = joiner.value(asType: MongoCursor<Document>.self)!
        XCTAssertEqual(["_id": insResult.insertedId ?? BSONNull(), "so": "syncy"] as Document, findResult.next())
        try ctx.streamAndSync()
        remote.find(["_id": doc3["_id"] ?? BSONNull()]).first(joiner.capture())
        var remoteFindResult: Document? = joiner.value()!
        XCTAssertNil(remoteFindResult)
        goOnline()
        try ctx.streamAndSync()
        remote.find(["_id": insResult.insertedId!], options: nil).first(joiner.capture())
        remoteFindResult = joiner.value()!
        XCTAssertEqual(["_id": insResult.insertedId ?? BSONNull(), "so": "syncy"],
                       SyncIntTestUtilities.withoutSyncVersion(remoteFindResult ?? [:]))

        // 3. updating a document locally that has been updated remotely should invoke the conflict
        // resolver.
        ctx.streamJoiner.clearEvents()
        remote.updateOne(
            filter: doc1Filter,
            update: SyncIntTestUtilities.withNewSyncVersionSet(doc1Update),
            joiner.capture())
        let result2 = joiner.capturedValue as! RemoteUpdateResult
        try ctx.watch(forEvents: 1)
        XCTAssertEqual(1, result2.matchedCount)
        expectedDocument["foo"] = 2
        remote.find(doc1Filter, options: nil).first(joiner.capture())
        remoteFindResult = joiner.value()
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteFindResult!))
        sync.updateOne(
            filter: ["_id": doc1Id],
            update: doc1Update,
            options: nil,
            joiner.capture())
        let result3 = joiner.value(asType: SyncUpdateResult.self)
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
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(joiner.value()!))
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
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(joiner.value()!))

        sync.verifyUndoCollectionEmpty()
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
                if localEvent.fullDocument!.keys.contains(it.key) {
                    return
                }
                merged[it.key] = it.value
            }
            return merged
        })
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()

        // Update remote
        let remoteUpdate = SyncIntTestUtilities.withNewSyncVersionSet(["$set": ["remote": "update"] as Document])
        let result = remote.updateOne(filter: doc1Filter, update: remoteUpdate)
        try ctx.watch(forEvents: 1)
        XCTAssertEqual(1, result.matchedCount)
        var expectedRemoteDocument = doc
        expectedRemoteDocument["remote"] = "update"
        XCTAssertEqual(expectedRemoteDocument, SyncIntTestUtilities.withoutSyncVersion(remote.findOne(doc1Filter)!))

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

        XCTAssertEqual(expectedRemoteDocument, SyncIntTestUtilities.withoutSyncVersion(remote.findOne(doc1Filter)!))
        expectedLocalDocument["remote"] = "update"

        XCTAssertEqual(expectedLocalDocument, coll.findOne(doc1Filter))

        // second pass will update with the ack'd version id
        try ctx.streamAndSync()

        XCTAssertEqual(expectedLocalDocument, coll.findOne(doc1Filter))
        XCTAssertEqual(expectedLocalDocument.sorted(),
                       SyncIntTestUtilities.withoutSyncVersion(remote.findOne(doc1Filter)!.sorted()))
        coll.verifyUndoCollectionEmpty()
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
        coll.configure(conflictHandler: DefaultConflictHandler<Document>.remoteWins())

        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()

        // update the document remotely while watching for an update
        var expectedDocument = doc
        let result = remote.updateOne(filter: doc1Filter, update: SyncIntTestUtilities.withNewSyncVersionSet(
            ["$inc": ["foo": 2] as Document]))
        try ctx.watch(forEvents: 1)

        // once the event has been stored,
        // fetch the remote document and assert that it has properly updated
        XCTAssertEqual(1, result.matchedCount)
        expectedDocument["foo"] = 3
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remote.findOne(doc1Filter)!))

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
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remote.findOne(doc1Filter)!))

        coll.verifyUndoCollectionEmpty()
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
        coll.configure(conflictHandler: DefaultConflictHandler<Document>.localWins())
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()

        // update the document remotely while watching for an update
        var expectedDocument = doc
        let result = remoteColl.updateOne(
            filter: doc1Filter,
            update: SyncIntTestUtilities.withNewSyncVersionSet(["$inc": ["foo": 2] as Document])
        )
        try ctx.watch(forEvents: 1)
        // once the event has been stored,
        // fetch the remote document and assert that it has properly updated
        XCTAssertEqual(1, result.matchedCount)
        expectedDocument["foo"] = 3
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))

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
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))

        coll.verifyUndoCollectionEmpty()
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
            XCTFail("did not expect a conflict")
            return nil
        }, changeEventDelegate: nil, errorListener: { (error, _) in
            XCTFail(error.localizedDescription)
        })
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()

        // update the document so it has a sync version (if we don't do this, then deleting
        // the document will result in a conflict because a remote document with no version
        // and a local document with no version are treated as documents with different
        // versions)
        _ = coll.updateOne(filter: doc1Filter, update: ["$set": ["hello": "universe"] as Document])
        try ctx.streamAndSync()
        doc = remoteColl.findOne(doc1Filter)!

        // go offline to avoid processing events.
        // delete the document locally
        goOffline()
        let result = coll.deleteOne(doc1Filter)
        XCTAssertEqual(1, result?.deletedCount)

        // assert that, while the remote document remains
        let expectedDocument = SyncIntTestUtilities.withoutSyncVersion(doc)
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertNil(coll.findOne(doc1Filter))

        // go online to begin the syncing process.
        // when syncing, our local delete will be synced to the remote.
        // assert that this is reflected remotely and locally
        goOnline()
        try ctx.streamAndSync()
        XCTAssertNil(remoteColl.findOne(doc1Filter))
        XCTAssertNil(coll.findOne(doc1Filter))

        coll.verifyUndoCollectionEmpty()
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
            update: SyncIntTestUtilities.withNewSyncVersionSet(doc1Update)).matchedCount)

        // go offline, and delete the document locally
        goOffline()
        let result = coll.deleteOne(doc1Filter)
        XCTAssertEqual(1, result?.deletedCount)

        // assert that the remote document has not been deleted,
        // while the local document has been
        var expectedDocument = doc
        expectedDocument["foo"] = 1
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertNil(coll.findOne(doc1Filter))

        // go back online and sync. assert that the remote document has been updated
        // while the local document reflects the resolution of the conflict
        goOnline()
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        expectedDocument = expectedDocument.filter { !($0.key == "hello" || $0.key == "foo") }
        expectedDocument["well"] = "shoot"
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        coll.verifyUndoCollectionEmpty()
    }

    func testInsertThenUpdateThenSync() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // configure Sync to fail this test if there is a conflict.
        // insert and sync the new document locally
        var docToInsert = ["hello": "world"] as Document
        coll.configure(conflictHandler: { (_, _, _) -> Document? in
            XCTFail("did not expect a conflict")
            return nil
        })
        let insertResult = coll.insertOne(&docToInsert)!

        // find the local document we just inserted
        let doc = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        let doc1Id = doc["_id"]
        let doc1Filter = ["_id": doc1Id ?? BSONNull()] as Document

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
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        coll.verifyUndoCollectionEmpty()
    }

    func testInsertThenSyncUpdateThenUpdate() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // configure Sync to fail this test if there is a conflict.
        // insert and sync the new document locally
        var docToInsert = ["hello": "world"] as Document
        coll.configure(conflictHandler: { _, _, _ in
            XCTFail("did not expect a conflict")
            return nil
        })
        let insertResult = coll.insertOne(&docToInsert)!

        // find the document we just inserted
        let doc = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        let doc1Id = doc["_id"]
        let doc1Filter = ["_id": doc1Id ?? BSONNull()] as Document

        // go online (in case we weren't already). sync.
        // assert that the local insertion reflects remotely
        goOnline()
        try ctx.streamAndSync()
        var expectedDocument = doc
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter)!)

        // update the document locally
        let doc1Update = ["$inc": ["foo": 1] as Document] as Document
        XCTAssertEqual(1, coll.updateOne(filter: doc1Filter, update: doc1Update)?.matchedCount)

        // assert that this update has not been reflected remotely, but has locally
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        expectedDocument["foo"] = 1
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter)!)

        // sync. assert that our update is reflected locally and remotely
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        coll.verifyUndoCollectionEmpty()
    }

    func testInsertThenSyncThenRemoveThenInsertThenUpdate() throws {
        let (remote, coll) = ctx.remoteCollAndSync

        // configure Sync to fail this test if there is a conflict.
        // insert and sync the new document locally. sync.
        var docToInsert: Document = ["hello": "world"]
        coll.configure(conflictHandler: { (_, _, _) -> Document? in
            XCTFail("did not expect a conflict")
            return nil
        })
        let insertResult = coll.insertOne(&docToInsert)!
        try ctx.streamAndSync()

        // assert the sync'd document is found locally and remotely
        var doc = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        let doc1Id = doc["_id"]
        let doc1Filter: Document = ["_id": doc1Id ?? BSONNull()]
        var expectedDocument = doc
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remote.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // delete the doc locally, then re-insert it.
        // assert the document is still the same locally and remotely
        XCTAssertEqual(1, coll.deleteOne(doc1Filter)?.deletedCount)
        coll.insertOne(&doc)
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remote.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // update the document locally
        let doc1Update = ["$inc": ["foo": 1] as Document] as Document
        XCTAssertEqual(1, coll.updateOne(filter: doc1Filter, update: doc1Update)?.matchedCount)

        // assert that the document has not been updated remotely yet,
        // but has locally
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remote.findOne(doc1Filter)!))
        expectedDocument["foo"] = 1
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // sync. assert that the update has been reflected remotely and locally
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remote.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        goOffline()

        coll.verifyUndoCollectionEmpty()
    }

    let failingConflictHandler = { (_: BSONValue, _: ChangeEvent<Document>, _: ChangeEvent<Document>) -> Document? in
        XCTFail("Conflict should not have occurred")
        return nil
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
        XCTAssertEqual(coll.syncedIds().count, 1)

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

        coll.verifyUndoCollectionEmpty()
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

        coll.verifyUndoCollectionEmpty()
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
        _ = remoteColl.insertOne(SyncIntTestUtilities.withNewSyncVersion(doc))
        try ctx.watch(forEvents: 2)

        // update the local document concurrently. sync.
        XCTAssertEqual(1, coll.updateOne(filter: doc1Filter, update: ["$inc": ["foo": 1] as Document])?.matchedCount)
        try ctx.streamAndSync()

        // assert that the remote doc has not reflected the update.
        // assert that the local document has received the resolution
        // from the conflict handled
        XCTAssertEqual(doc, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        var expectedDocument = ["_id": doc1Id] as Document
        expectedDocument["hello"] = "again"
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // do another sync pass. assert that the local and remote docs are in sync
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter)!)

        coll.verifyUndoCollectionEmpty()
    }

    func testRemoteInsertsWithVersionLocalUpdates() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a document remotely
        let docToInsert = ["hello": "world"] as Document
        remoteColl.insertOne(SyncIntTestUtilities.withNewSyncVersion(docToInsert))

        // find the document we just inserted
        let doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        // configure Sync to fail this test if there is a conflict.
        // sync the document, and do a sync pass.
        // assert the remote insertion is reflected locally.
        coll.configure(conflictHandler: failingConflictHandler)
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()
        XCTAssertEqual(SyncIntTestUtilities.withoutSyncVersion(doc), coll.findOne(doc1Filter))

        // update the document locally. sync.
        XCTAssertEqual(
            1,
            coll.updateOne(filter: doc1Filter, update: ["$inc": ["foo": 1] as Document] as Document)?.matchedCount
        )
        try ctx.streamAndSync()

        // assert that the local update has been reflected remotely.
        var expectedDocument = SyncIntTestUtilities.withoutSyncVersion(doc)
        expectedDocument["foo"] = 1
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        coll.verifyUndoCollectionEmpty()
    }

    func testResolveConflictWithDelete() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a new document remotely
        let docToInsert = ["hello": "world"] as Document
        remoteColl.insertOne(SyncIntTestUtilities.withNewSyncVersion(docToInsert))

        // find the document we just inserted
        let doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        // configure Sync to resolve null when conflicted, effectively deleting
        // the conflicted document.
        // sync the docId, and do a sync pass.
        // assert the remote insert is reflected locally
        coll.configure(conflictHandler: { _, _, _ in nil })
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()
        XCTAssertEqual(SyncIntTestUtilities.withoutSyncVersion(doc), coll.findOne(doc1Filter))
        XCTAssertNotNil(coll.findOne(doc1Filter))

        // update the document remotely. wait for the update event to store.
        XCTAssertEqual(1, remoteColl.updateOne(
            filter: doc1Filter,
            update: SyncIntTestUtilities.withNewSyncVersionSet(
                ["$inc": ["foo": 1] as Document] as Document)).matchedCount
        )
        try ctx.watch(forEvents: 1)

        // update the document locally.
        XCTAssertEqual(1, coll.updateOne(filter: doc1Filter, update: ["$inc": ["foo": 1] as Document])?.matchedCount)

        // sync. assert that the remote document has received that update,
        // but locally the document has resolved to deletion
        try ctx.streamAndSync()
        var expectedDocument = SyncIntTestUtilities.withoutSyncVersion(doc)
        expectedDocument["foo"] = 1
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        goOffline()
        XCTAssertNil(coll.findOne(doc1Filter))

        // go online and sync. the deletion should be reflected remotely and locally now
        goOnline()
        try ctx.streamAndSync()
        XCTAssertNil(remoteColl.findOne(doc1Filter))
        XCTAssertNil(coll.findOne(doc1Filter))

        coll.verifyUndoCollectionEmpty()
    }

    func testTurnDeviceOffAndOn() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a document remotely
        var docToInsert = ["hello": "world"] as Document
        docToInsert["foo"] = 1
        remoteColl.insertOne(docToInsert)

        // find the document we just inserted
        let doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        // reload our configuration
        try ctx.powerCycleDevice()

        // configure Sync to resolve conflicts with a local win.
        // sync the docId
        coll.configure(conflictHandler: DefaultConflictHandler<Document>.localWins())
        coll.sync(ids: [doc1Id])

        // reload our configuration again.
        // reconfigure sync and the same way. do a sync pass.
        try ctx.powerCycleDevice()
        coll.configure(conflictHandler: DefaultConflictHandler<Document>.localWins())
        try ctx.streamAndSync()

        // update the document remotely. assert the update is reflected remotely.
        // reload our configuration again. reconfigure Sync again.
        var expectedDocument = doc
        let result = remoteColl.updateOne(
            filter: doc1Filter,
            update: SyncIntTestUtilities.withNewSyncVersionSet(["$inc": ["foo": 2] as Document] as Document)
        )
        try ctx.watch(forEvents: 1)
        XCTAssertEqual(1, result.matchedCount)
        expectedDocument["foo"] = 3
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        try ctx.powerCycleDevice()
        coll.configure(conflictHandler: DefaultConflictHandler<Document>.localWins())

        // update the document locally. assert its success, after reconfiguration.
        let localResult = coll.updateOne(filter: doc1Filter, update: ["$inc": ["foo": 1] as Document])
        XCTAssertEqual(1, localResult?.matchedCount)

        expectedDocument["foo"] = 2
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // reconfigure again.
        try ctx.powerCycleDevice()
        coll.configure(conflictHandler: DefaultConflictHandler<Document>.localWins())

        // sync.
        try ctx.streamAndSync() // does nothing with no conflict handler

        // assert we are still synced on one id.
        // reconfigure again.
        XCTAssertEqual(1, coll.syncedIds().count)
        coll.configure(conflictHandler: DefaultConflictHandler<Document>.localWins())
        try ctx.streamAndSync() // resolves the conflict

        // assert the update was reflected locally. reconfigure again.
        expectedDocument["foo"] = 2
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))
        try ctx.powerCycleDevice()
        coll.configure(conflictHandler: DefaultConflictHandler<Document>.localWins())

        // sync. assert that the update was reflected remotely
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))

        coll.verifyUndoCollectionEmpty()
    }

    func testDesync() throws {
        let coll = ctx.remoteCollAndSync.1

        // insert and sync a new document.
        // configure Sync to fail this test if there is a conflict.
        var docToInsert = ["hello": "world"] as Document
        coll.configure(conflictHandler: failingConflictHandler)
        let doc1Id = coll.insertOne(&docToInsert)!.insertedId!

        // assert the document exists locally. desync it.
        XCTAssertEqual(docToInsert.sorted(), coll.findOne(["_id": doc1Id]))
        coll.desync(ids: [doc1Id])

        // sync. assert that the desync'd document no longer exists locally
        try ctx.streamAndSync()
        XCTAssertNil(coll.findOne(["_id": doc1Id]))

        coll.verifyUndoCollectionEmpty()
    }

    func testInsertInsertConflict() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a new document remotely
        var docToInsert = Document()
        let insertOneResult = remoteColl.insertOne(docToInsert)!
        docToInsert["_id"] = insertOneResult.insertedId
        // configure Sync to resolve a custom document when handling a conflict
        // insert and sync the same document locally, creating a conflict
        coll.configure(conflictHandler: { _, _, _ in
            return ["friend": "welcome"]
        })
        let doc1Id = coll.insertOne(&docToInsert)!.insertedId
        let doc1Filter = ["_id": doc1Id ?? BSONNull()] as Document

        // sync. assert that the resolution is reflected locally,
        // but not yet remotely.
        try ctx.streamAndSync()
        var expectedDocument = doc1Filter
        expectedDocument["friend"] = "welcome"
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))
        XCTAssertEqual(docToInsert, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))

        // sync again. assert that the resolution is reflected
        // locally and remotely.
        try ctx.streamAndSync()
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))

        coll.verifyUndoCollectionEmpty()
    }

    func testConfigure() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a document locally
        var docToInsert = ["hello": "world"] as Document
        let insertedId = coll.insertOne(&docToInsert)!.insertedId

        var hasConflictHandlerBeenInvoked = false
        var hasChangeEventListenerBeenInvoked = false

        // configure Sync, each entry with flags checking
        // that the listeners/handlers have been called
        let changeEventListenerSemaphore = DispatchSemaphore.init(value: 0)
        coll.configure(conflictHandler: { _, _, remoteEvent in
            hasConflictHandlerBeenInvoked = true
            XCTAssertEqual(remoteEvent.fullDocument?["fly"] as? String, "away")
            return remoteEvent.fullDocument
        },
        changeEventDelegate: { _, _ in
            hasChangeEventListenerBeenInvoked = true
            changeEventListenerSemaphore.signal()
        },
        errorListener: nil
        )

        // insert a document remotely
        remoteColl.insertOne(["_id": insertedId ?? BSONNull(), "fly": "away"])

        // sync. assert that the conflict handler and
        // change event listener have been called
        try ctx.streamAndSync()

        guard case .success = changeEventListenerSemaphore
            .wait(timeout: DispatchTime.init(uptimeNanoseconds: UInt64(1e+10))) else {
            XCTFail("did not expect a conflict")
            return
        }
        XCTAssertTrue(hasConflictHandlerBeenInvoked)
        XCTAssertTrue(hasChangeEventListenerBeenInvoked)

        coll.verifyUndoCollectionEmpty()
    }

    func testSyncVersioningScheme() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        var docToInsert = ["hello": "world"] as Document

        coll.configure(conflictHandler: failingConflictHandler)
        let insertResult = coll.insertOne(&docToInsert)!

        var doc = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        let doc1Id = doc["_id"]
        let doc1Filter = ["_id": doc1Id ?? BSONNull()] as Document

        goOnline()
        try ctx.streamAndSync()
        var expectedDocument = doc

        // the remote document after an initial insert should have a fresh instance ID, and a
        // version counter of 0
        let firstRemoteDoc = remoteColl.findOne(doc1Filter)!
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(firstRemoteDoc))

        XCTAssertEqual(0, SyncIntTestUtilities.versionCounterOf(firstRemoteDoc))

        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // the remote document after a local update, but before a sync pass, should have the
        // same version as the original document, and be equivalent to the unupdated document
        let doc1Update = ["$inc": ["foo": 1] as Document] as Document
        XCTAssertEqual(1, coll.updateOne(filter: doc1Filter, update: doc1Update)?.matchedCount)

        let secondRemoteDocBeforeSyncPass = remoteColl.findOne(doc1Filter)!
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(secondRemoteDocBeforeSyncPass))
        XCTAssertEqual(SyncIntTestUtilities.versionOf(firstRemoteDoc),
                       SyncIntTestUtilities.versionOf(secondRemoteDocBeforeSyncPass))

        expectedDocument["foo"] = 1
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // the remote document after a local update, and after a sync pass, should have a new
        // version with the same instance ID as the original document, a version counter
        // incremented by 1, and be equivalent to the updated document.
        try ctx.streamAndSync()
        let secondRemoteDoc = remoteColl.findOne(doc1Filter)!
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(secondRemoteDoc))
        XCTAssertEqual(SyncIntTestUtilities.instanceIdOf(firstRemoteDoc),
                       SyncIntTestUtilities.instanceIdOf(secondRemoteDoc))
        XCTAssertEqual(1, SyncIntTestUtilities.versionCounterOf(secondRemoteDoc))

        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // the remote document after a local delete and local insert, but before a sync pass,
        // should have the same version as the previous document
        XCTAssertEqual(1, coll.deleteOne(doc1Filter)!.deletedCount)
        coll.insertOne(&doc)

        let thirdRemoteDocBeforeSyncPass = remoteColl.findOne(doc1Filter)!
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(thirdRemoteDocBeforeSyncPass))

        expectedDocument = expectedDocument.filter({ $0.key != "foo" })
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        // the remote document after a local delete and local insert, and after a sync pass,
        // should have the same instance ID as before and a version count, since the change
        // events are coalesced into a single update event
        try ctx.streamAndSync()

        let thirdRemoteDoc = remoteColl.findOne(doc1Filter)!
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(thirdRemoteDoc))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        XCTAssertEqual(SyncIntTestUtilities.instanceIdOf(secondRemoteDoc),
                       SyncIntTestUtilities.instanceIdOf(thirdRemoteDoc))
        XCTAssertEqual(2, SyncIntTestUtilities.versionCounterOf(thirdRemoteDoc))

        // the remote document after a local delete, a sync pass, a local insert, and after
        // another sync pass should have a new instance ID, with a version counter of zero,
        // since the change events are not coalesced
        XCTAssertEqual(1, coll.deleteOne(doc1Filter)?.deletedCount)
        try ctx.streamAndSync()
        coll.insertOne(&doc)
        try ctx.streamAndSync()

        let fourthRemoteDoc = remoteColl.findOne(doc1Filter)!
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(thirdRemoteDoc))
        XCTAssertEqual(expectedDocument, coll.findOne(doc1Filter))

        XCTAssertNotEqual(SyncIntTestUtilities.instanceIdOf(secondRemoteDoc),
                          SyncIntTestUtilities.instanceIdOf(fourthRemoteDoc))
        XCTAssertEqual(0, SyncIntTestUtilities.versionCounterOf(fourthRemoteDoc))

        coll.verifyUndoCollectionEmpty()
    }

    func testUnsupportedSpvFails() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        let docToInsert = SyncIntTestUtilities.withNewUnsupportedSyncVersion(["hello": "world"])

        let errorEmittedSem = DispatchSemaphore.init(value: 0)
        coll.configure(
            conflictHandler: failingConflictHandler,
            changeEventDelegate: nil,
            errorListener: { _, _ in errorEmittedSem.signal() })

        remoteColl.insertOne(docToInsert)

        let doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        coll.sync(ids: [doc1Id])

        XCTAssertTrue(coll.syncedIds().contains(AnyBSONValue(doc1Id)))

        // syncing on this document with an unsupported spv should cause the document to desync
        goOnline()
        try ctx.streamAndSync()

        XCTAssertFalse(coll.syncedIds().contains(AnyBSONValue(doc1Id)))

        // an error should also have been emitted
        guard case .success = errorEmittedSem.wait(timeout: DispatchTime(uptimeNanoseconds: waitTimeout)) else {
            XCTFail("did not expect a conflict")
            return
        }

        coll.verifyUndoCollectionEmpty()
    }

    func testStaleFetchSingle() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a new document
        let doc1 = ["hello": "world"] as Document
        remoteColl.insertOne(doc1)

        // find the document we just inserted
        let doc = remoteColl.findOne(doc1)!
        let doc1Id = doc["_id"]!

        // configure Sync with a conflict handler that will freeze a document.
        // sync the document
        coll.configure(conflictHandler: failingConflictHandler)
        coll.sync(ids: [doc1Id])

        // sync. assert the document has been synced.
        try ctx.streamAndSync()
        XCTAssertNotNil(coll.findOne(["_id": doc1Id]))

        // update the document locally.
        _ = coll.updateOne(filter: ["_id": doc1Id], update: ["$inc": ["i": 1] as Document])

        // sync. assert the document still exists
        try ctx.streamAndSync()
        XCTAssertNotNil(coll.findOne(["_id": doc1Id]))

        // sync. assert the document still exists
        try ctx.streamAndSync()
        XCTAssertNotNil(coll.findOne(["_id": doc1Id]))

        coll.verifyUndoCollectionEmpty()
    }

    func testStaleFetchSingleDeleted() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        let doc1 = ["hello": "world"] as Document
        remoteColl.insertOne(doc1)

        // get the document
        let doc = remoteColl.findOne(doc1)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        coll.configure(conflictHandler: { _, _, _ in
            XCTFail("did not expect a conflict")
            return nil
        })
        coll.sync(ids: [doc1Id])

        try ctx.streamAndSync()
        XCTAssertNotNil(coll.findOne(doc1Filter))

        _ = coll.updateOne(filter: doc1Filter, update: ["$inc": ["i": 1] as Document])
        try ctx.streamAndSync()
        XCTAssertNotNil(coll.findOne(doc1Filter))

        XCTAssertEqual(1, remoteColl.deleteOne(doc1Filter)?.deletedCount)
        try ctx.powerCycleDevice()
        coll.configure(conflictHandler: { _, _, _ in
            XCTFail("did not expect a conflict")
            return nil
        })

        try ctx.streamAndSync()
        XCTAssertNil(coll.findOne(doc1Filter))

        coll.verifyUndoCollectionEmpty()
    }

    func testStaleFetchMultiple() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        let insertResult =
            remoteColl.insertMany([
                ["hello": "world"] as Document,
                ["hello": "friend"] as Document])!

        // get the document
        let doc1Id = insertResult.insertedIds[0]!
        let doc2Id = insertResult.insertedIds[1]!

        coll.configure(conflictHandler: { _, _, _ in
            XCTFail("did not expect a conflict")
            return nil
        })
        coll.sync(ids: [doc1Id])

        try ctx.streamAndSync()
        XCTAssertNotNil(coll.findOne(["_id": doc1Id]))

        _ = coll.updateOne(filter: ["_id": doc1Id], update: ["$inc": ["i": 1] as Document])
        try ctx.streamAndSync()
        XCTAssertNotNil(coll.findOne(["_id": doc1Id]))

        coll.sync(ids: [doc2Id])
        try ctx.streamAndSync()
        XCTAssertNotNil(coll.findOne(["_id": doc1Id]))
        XCTAssertNotNil(coll.findOne(["_id": doc2Id]))

        coll.verifyUndoCollectionEmpty()
    }

    func testShouldUpdateUsingUpdateDescription() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        let docToInsert = [
            "i_am": "the walrus",
            "they_are": "the egg men",
            "members": [
                "paul", "john", "george", "pete"
            ],
            "where_to_be": [
                "under_the_sea": [
                    "octopus_garden": "in the shade"
                    ] as Document,
                "the_land_of_submarines": [
                    "a_yellow_submarine": "a yellow submarine"
                    ] as Document
                ] as Document,
            "year": 1960
            ] as Document
        let docAfterUpdate = try Document(fromJSON: """
        {
        "i_am": "the egg men",
        "they_are": "the egg men",
        "members": [ "paul", "john", "george", "ringo" ],
        "where_to_be": {
        "under_the_sea": {
        "octopus_garden": "near a cave"
        },
        "the_land_of_submarines": {
        "a_yellow_submarine": "a yellow submarine"
        }
        }
        }
        """)
        let updateDoc = try Document(fromJSON: """
        {
        "$set": {
        "i_am": "the egg men",
        "members": [ "paul", "john", "george", "ringo" ],
        "where_to_be.under_the_sea.octopus_garden": "near a cave"
        },
        "$unset": {
        "year": true
        }
        }
        """)

        remoteColl.insertOne(docToInsert)
        let doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]!
        let doc1Filter = ["_id": doc1Id] as Document

        let eventSemaphore = DispatchSemaphore(value: 0)
        coll.configure(conflictHandler: failingConflictHandler, changeEventDelegate: { _, event in
            // ensure that there is no version information in the event document.
            SyncIntTestUtilities.assertNoVersionFieldsInDoc(event.fullDocument!)

            if event.operationType == .update && !event.hasUncommittedWrites {
                XCTAssertEqual(
                    updateDoc["$set"] as? Document,
                    event.updateDescription?.updatedFields)
                XCTAssertEqual(
                    updateDoc["$unset"] as? Document,
                    try? event.updateDescription?.removedFields.reduce(
                        Document(), { (doc: Document, field: String) throws -> Document in
                            var doc = doc
                            doc[field] = true
                            return doc
                        }))
                eventSemaphore.signal()
            }
        }, errorListener: nil)
        coll.sync(ids: [doc1Id])
        try ctx.streamAndSync()

        // because the "they_are" field has already been added, set
        // a rule that prevents writing to the "they_are" field that we've added.
        // a full replace would therefore break our rule, preventing validation.
        // only an actual update document (with $set and $unset)
        // can work for the rest of this test
        try mdbService.rules.rule(withID: mdbRule.id).remove()
        let result = coll.updateOne(filter: doc1Filter, update: updateDoc)
        XCTAssertEqual(1, result?.matchedCount)
        XCTAssertEqual(docAfterUpdate, SyncIntTestUtilities.withoutId(coll.findOne(doc1Filter)!))

        // set they_are to unwriteable. the update should only update i_am
        // setting i_am to false and they_are to true would fail this test
        _ = try mdbService.rules.create(
            data: RuleCreator.mongoDb(
                database: dbName,
                collection: collName,
                roles: [
                    RuleCreator.Role(
                        fields: [
                            "i_am": ["write": true] as Document,
                            "they_are": ["write": false] as Document,
                            "where_to_be.the_land_of_submarines": ["write": false] as Document
                        ]
                    )
                ],
                schema: RuleCreator.Schema()
            )
        )

        try ctx.streamAndSync()
        XCTAssertEqual(docAfterUpdate, SyncIntTestUtilities.withoutId(coll.findOne(doc1Filter)!))
        XCTAssertEqual(docAfterUpdate, SyncIntTestUtilities.withoutId(
            SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!)))
        guard case .success = eventSemaphore.wait(timeout: DispatchTime(uptimeNanoseconds: waitTimeout)) else {
            XCTFail("did not expect a conflict")
            return
        }

        coll.verifyUndoCollectionEmpty()
    }

    func testResumeSyncForDocumentResumesSync() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync
        var errorEmitted = false

        var conflictCounter = 0

        coll.configure(conflictHandler: { (_, _, remoteEvent) throws -> Document? in
            if conflictCounter == 0 {
                conflictCounter += 1
                errorEmitted = true
                throw "ouch"
            }
            return remoteEvent.fullDocument
        })

        // insert an initial doc
        var testDoc = ["hello": "world"] as Document
        let result = coll.insertOne(&testDoc)

        // do a sync pass, synchronizing the doc
        try ctx.streamAndSync()
        ctx.streamJoiner.clearEvents()

        XCTAssertNotNil(remoteColl.findOne(["_id": testDoc["_id"] ?? BSONNull()]))

        // update the doc
        let expectedDoc = ["hello": "computer"] as Document
        _ = coll.updateOne(filter: ["_id": result?.insertedId ?? BSONNull()], update: ["$set": expectedDoc])

        // create a conflict
        _ = remoteColl.updateOne(
            filter: ["_id": result?.insertedId ?? BSONNull()],
            update: SyncIntTestUtilities.withNewSyncVersionSet(["$inc": ["foo": 2] as Document])
        )
        try ctx.watch(forEvents: 1)

        // do a sync pass, and throw an error during the conflict resolved freezing the document
        try ctx.streamAndSync()
        ctx.streamJoiner.clearEvents()
        XCTAssertTrue(errorEmitted)
        XCTAssertEqual(1, coll.pausedIds().count)
        XCTAssertTrue(coll.pausedIds().contains(AnyBSONValue(result!.insertedId!)))

        // update the doc remotely
        let nextDoc = ["hello": "friend"] as Document
        _ = remoteColl.updateOne(filter: ["_id": result?.insertedId ?? BSONNull()], update: nextDoc)
        try ctx.watch(forEvents: 1)
        try ctx.streamAndSync()
        ctx.streamJoiner.clearEvents()

        // it should not have updated the local doc, as the local doc should be paused
        XCTAssertEqual(
            SyncIntTestUtilities.withoutId(expectedDoc),
            SyncIntTestUtilities.withoutId(coll.findOne(["_id": result?.insertedId ?? BSONNull()])!)
        )

        // resume syncing here
        XCTAssertTrue(coll.resumeSync(forDocumentId: result!.insertedId!))
        try ctx.streamAndSync()
        ctx.streamJoiner.clearEvents()

        // update the doc remotely
        let lastDoc = ["good night": "computer"] as Document

        _ = remoteColl.updateOne(filter: ["_id": result?.insertedId ?? BSONNull()],
                                 update: SyncIntTestUtilities.withNewSyncVersion(lastDoc))
        try ctx.watch(forEvents: 1)
        ctx.streamJoiner.clearEvents()

        // now that we're sync'd and resumed, it should be reflected locally
        try ctx.streamAndSync()
        ctx.streamJoiner.clearEvents()

        XCTAssertTrue(coll.pausedIds().isEmpty)
        XCTAssertEqual(
            SyncIntTestUtilities.withoutId(lastDoc),
            SyncIntTestUtilities.withoutId(coll.findOne(["_id": result?.insertedId ?? BSONNull()])!)
        )

        coll.verifyUndoCollectionEmpty()
    }

    func testReadsBeforeAndAfterSync() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        coll.configure(conflictHandler: failingConflictHandler)

        let doc1 = ["hello": "world"] as Document
        let doc2 = ["hello": "friend"] as Document
        let doc3 = ["hello": "goodbye"] as Document

        let insertResult = remoteColl.insertMany([doc1, doc2, doc3])
        XCTAssertEqual(3, insertResult?.insertedIds.count)

        XCTAssertEqual(0, coll.count([:]))
        XCTAssertEqual(0, coll.find([:])?.compactMap({ $0 }).count)
        XCTAssertEqual(0, coll.aggregate([[
            "$match": ["_id":
                ["$in": insertResult?.insertedIds.compactMap({ $1 }) ?? BSONNull()] as Document] as Document
            ]])?.compactMap({ $0 }).count)

        insertResult?.insertedIds.forEach({
            coll.sync(ids: [$1])
        })
        try ctx.streamAndSync()

        XCTAssertEqual(3, coll.count([:]))
        XCTAssertEqual(3, coll.find([:])?.compactMap({ $0 }).count)
        XCTAssertEqual(3, coll.aggregate([[
            "$match": ["_id": ["$in": insertResult?.insertedIds.map({ $1 }) ?? BSONNull()] as Document] as Document
            ]])?.compactMap({ $0 }).count)

        insertResult?.insertedIds.forEach({
            coll.desync(ids: [$1])
        })
        try ctx.streamAndSync()

        XCTAssertEqual(0, coll.count([:]))
        XCTAssertEqual(0, coll.find([:])?.compactMap({ $0 }).count)
        XCTAssertEqual(0, coll.aggregate([[
            "$match": ["_id": ["$in": insertResult?.insertedIds.map({ $1 }) ?? BSONNull()] as Document] as Document
            ]])?.compactMap({ $0 }).count)

        coll.verifyUndoCollectionEmpty()
    }

    func testInsertManyNoConflicts() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        coll.configure(conflictHandler: failingConflictHandler)

        var docs: [Document] = [["hello": "world"], ["hello": "friend"], ["hello": "goodbye"]]
        let insertResult = coll.insertMany(&docs)
        let doc1 = docs[0]
        let doc2 = docs[1]
        let doc3 = docs[2]

        XCTAssertEqual(3, insertResult?.insertedIds.count)

        XCTAssertEqual(3, coll.count([:]))
        XCTAssertEqual(3, coll.find([:])?.compactMap({ $0 }).count)
        XCTAssertEqual(3, coll.aggregate([[
            "$match": ["_id":
                ["$in": insertResult?.insertedIds.compactMap({ $1 })  ?? BSONNull()] as Document] as Document
        ]])?.compactMap({ $0 }).count)

        XCTAssertEqual(0, remoteColl.find([:])?.count)
        try ctx.streamAndSync()

        XCTAssertEqual(3, remoteColl.find([:])?.count)

        XCTAssertEqual(doc1.sorted(),
                       SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(
                        ["_id": doc1["_id"]!])!.sorted()))
        XCTAssertEqual(doc2.sorted(),
                       SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(
                        ["_id": doc2["_id"] ?? BSONNull()])!.sorted()))
        XCTAssertEqual(doc3.sorted(),
                       SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(
                        ["_id": doc3["_id"] ?? BSONNull()])!.sorted()))

        coll.verifyUndoCollectionEmpty()
    }

    func testUpdateManyNoConflicts() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        coll.configure(conflictHandler: failingConflictHandler)

        var updateResult = coll.updateMany(
            filter: ["fish": ["one", "two", "red", "blue"]],
            update: ["$set": ["fish": ["black", "blue", "old", "new"]] as Document]
        )!

        XCTAssertEqual(0, updateResult.modifiedCount)
        XCTAssertEqual(0, updateResult.matchedCount)
        XCTAssertNil(updateResult.upsertedId)

        updateResult = coll.updateMany(
            filter: ["fish": ["one", "two", "red", "blue"]],
            update: ["$set": ["fish": ["black", "blue", "old", "new"]] as Document],
            options: SyncUpdateOptions(upsert: true)
        )!

        XCTAssertEqual(0, updateResult.modifiedCount)
        XCTAssertEqual(0, updateResult.matchedCount)
        XCTAssertNotNil(updateResult.upsertedId)

        let doc1 = [
            "hello": "world",
            "fish": ["one", "two", "red", "blue"]
        ] as Document
        let doc2 = ["hello": "friend"] as Document
        let doc3 = ["hello": "goodbye"] as Document

        var docs = [doc1, doc2, doc3]
        let insertResult = coll.insertMany(&docs)
        XCTAssertEqual(3, insertResult?.insertedIds.count)

        try ctx.streamAndSync()

        XCTAssertEqual(4, remoteColl.find([:])?.count)

        updateResult = coll.updateMany(
            filter: ["fish": ["$exists": true] as Document],
            update: ["$set": ["fish": ["trout", "mackerel", "cod", "hake"]] as Document]
        )!

        XCTAssertEqual(2, updateResult.modifiedCount)
        XCTAssertEqual(2, updateResult.matchedCount)
        XCTAssertNil(updateResult.upsertedId)

        XCTAssertEqual(4, coll.count([:]))

        var localFound = coll.find(["fish": ["$exists": true] as Document])!
        XCTAssertEqual(2, localFound.map({ $0 }).count)
        localFound.forEach({ doc in
            XCTAssertEqual(["trout", "mackerel", "cod", "hake"], doc["fish"] as? [String])
        })

        try ctx.streamAndSync()

        let remoteFound = remoteColl.find(["fish": ["$exists": true] as Document])!
        localFound = coll.find(["fish": ["$exists": true] as Document])!

        XCTAssertEqual(2, localFound.map({ $0 }).count)
        XCTAssertEqual(2, remoteFound.map({ $0 }).count)

        localFound.forEach({ doc in
            XCTAssertEqual(["trout", "mackerel", "cod", "hake"], doc["fish"] as? [String])
        })
        remoteFound.forEach({ doc in
            XCTAssertEqual(["trout", "mackerel", "cod", "hake"], doc["fish"] as? [String])
        })

        coll.verifyUndoCollectionEmpty()
    }

    func testDeleteManyNoConflicts() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        coll.configure(conflictHandler: failingConflictHandler)

        var docs: [Document] = [["hello": "world"], ["hello": "friend"], ["hello": "goodbye"]]
        let insertResult = coll.insertMany(&docs)

        XCTAssertEqual(3, insertResult?.insertedIds.count)

        XCTAssertEqual(3, coll.count([:]))
        XCTAssertEqual(3, coll.find([:])?.compactMap({ $0 }).count)
        XCTAssertEqual(3, coll.aggregate(
            [["$match": [
                "_id": [
                    "$in": insertResult?.insertedIds.compactMap({ $1 }) ?? BSONNull()] as Document
                ] as Document] as Document]
            )?.map({ $0 }).count)

        XCTAssertEqual(0, remoteColl.find([:])?.count)
        try ctx.streamAndSync()

        XCTAssertEqual(3, remoteColl.find([:])?.count)
        _ = coll.deleteMany(["_id": ["$in": insertResult?.insertedIds.compactMap({ $1 }) ?? BSONNull()] as Document])

        XCTAssertEqual(3, remoteColl.find([:])?.count)
        XCTAssertEqual(0, coll.find([:])?.compactMap({ $0 }).count)

        try ctx.streamAndSync()

        XCTAssertEqual(0, remoteColl.find([:])?.count)
        XCTAssertEqual(0, coll.find([:])?.compactMap({ $0 }).count)
    }

    func testSyncVersionFieldNotEditable() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // configure Sync to fail this test if there is a conflict.

        // 0. insert with bad version
        // insert and sync a new document locally with a bad version field, and make sure it
        // doesn't exist after the insert
        let badVersionDoc = ["bad": "version"] as Document
        var docToInsert = [
            "hello": "world",
            "__stitch_sync_version": badVersionDoc
        ] as Document
        coll.configure(conflictHandler: failingConflictHandler)
        let insertResult = coll.insertOne(&docToInsert)!
        let localDocBeforeSync0 = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        XCTAssertFalse(SyncIntTestUtilities.hasVersionField(localDocBeforeSync0))

        try ctx.streamAndSync()

        // assert the sync'd document is found locally and remotely, and that the version
        // doesn't exist locally, and isn't the bad version doc remotely
        let localDocAfterSync0 = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        let docId = localDocAfterSync0["_id"]
        let docFilter = ["_id": docId ?? BSONNull()] as Document

        let remoteDoc0 = remoteColl.findOne(docFilter)!
        let remoteVersion0 = SyncIntTestUtilities.versionOf(remoteDoc0)

        let expectedDocument0 = localDocAfterSync0
        XCTAssertEqual(expectedDocument0, SyncIntTestUtilities.withoutSyncVersion(remoteDoc0))
        XCTAssertEqual(expectedDocument0, localDocAfterSync0)
        XCTAssertNotEqual(badVersionDoc, remoteVersion0)
        XCTAssertEqual(0, SyncIntTestUtilities.versionCounterOf(remoteDoc0))

        // 1. $set bad version counter

        // update the document, setting the version counter to 10, and a future version that
        // we'll try to maliciously set but verify that before and after syncing, there is no
        // version on the local doc, and that the version on the remote doc after syncing is
        // correctly incremented by only one.
        _ = coll.updateOne(
            filter: docFilter,
            update: ["$set": [
                "__stitch_sync_version.v": 10,
                "futureVersion": badVersionDoc
            ] as Document]
        )

        let localDocBeforeSync1 = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        XCTAssertFalse(SyncIntTestUtilities.hasVersionField(localDocBeforeSync1))
        try ctx.streamAndSync()

        let localDocAfterSync1 = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        let remoteDoc1 = remoteColl.findOne(docFilter)!
        let expectedDocument1 = localDocAfterSync1
        XCTAssertEqual(expectedDocument1, SyncIntTestUtilities.withoutSyncVersion(remoteDoc1))
        XCTAssertEqual(expectedDocument1, localDocAfterSync1)

        // verify the version only got incremented once
        XCTAssertEqual(1, SyncIntTestUtilities.versionCounterOf(remoteDoc1))

        // 2. $rename bad version doc

        // update the document, renaming our bad "futureVersion" field to
        // "__stitch_sync_version", and assert that there is no version on the local doc, and
        // that the version on the remote doc after syncing is correctly not incremented
        _ = coll.updateOne(
            filter: docFilter,
            update: ["$rename": ["futureVersion": "__stitch_sync_version"] as Document]
        )

        let localDocBeforeSync2 = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        XCTAssertFalse(SyncIntTestUtilities.hasVersionField(localDocBeforeSync2))
        try ctx.streamAndSync()

        let localDocAfterSync2 = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        let remoteDoc2 = remoteColl.findOne(docFilter)!

        // the expected doc is the doc without the futureVersion field (localDocAfterSync0)
        XCTAssertEqual(localDocAfterSync0, SyncIntTestUtilities.withoutSyncVersion(remoteDoc2))
        XCTAssertEqual(localDocAfterSync0, localDocAfterSync2)

        // verify the version did get incremented
        XCTAssertEqual(2, SyncIntTestUtilities.versionCounterOf(remoteDoc2))

        // 3. unset

        // update the document, unsetting "__stitch_sync_version", and assert that there is no
        // version on the local doc, and that the version on the remote doc after syncing
        // is correctly not incremented because is basically a noop.
        _ = coll.updateOne(
            filter: docFilter,
            update: ["$unset": ["__stitch_sync_version": 1] as Document]
        )

        let localDocBeforeSync3 = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        XCTAssertFalse(SyncIntTestUtilities.hasVersionField(localDocBeforeSync3))
        try ctx.streamAndSync()

        let localDocAfterSync3 = coll.findOne(["_id": insertResult.insertedId ?? BSONNull()])!
        let remoteDoc3 = remoteColl.findOne(docFilter)!

        // the expected doc is the doc without the futureVersion field (localDocAfterSync0)
        XCTAssertEqual(localDocAfterSync0, SyncIntTestUtilities.withoutSyncVersion(remoteDoc3))
        XCTAssertEqual(localDocAfterSync0, localDocAfterSync3)

        // verify the version did not get incremented, because this update was a noop
        XCTAssertEqual(2, SyncIntTestUtilities.versionCounterOf(remoteDoc3))

        coll.verifyUndoCollectionEmpty()
    }

    func testConflictForEmptyVersionDocuments() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        // insert a document remotely
        let docToInsert = ["hello": "world"] as Document
        remoteColl.insertOne(docToInsert)

        // find the document we just inserted
        var doc = remoteColl.findOne(docToInsert)!
        let doc1Id = doc["_id"]
        let doc1Filter = ["_id": doc1Id ?? BSONNull()] as Document

        // configure Sync to have local documents win conflicts
        var conflictRaised = false
        coll.configure(conflictHandler: {_, localEvent, _ in
            conflictRaised = true
            return localEvent.fullDocument
        })
        coll.sync(ids: [doc1Id!])
        try ctx.streamAndSync()

        // go offline to avoid processing events
        // delete the document locally
        goOffline()
        let result = coll.deleteOne(doc1Filter)
        XCTAssertEqual(1, result?.deletedCount)

        // assert that the remote document remains
        let expectedDocument = SyncIntTestUtilities.withoutSyncVersion(doc)
        XCTAssertEqual(expectedDocument, SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!))
        XCTAssertNil(coll.findOne(doc1Filter))

        // go online to begin the syncing process. A conflict should have
        // occurred because both the local and remote instance of this document have no version
        // information, meaning that the sync pass was forced to raise a conflict. our local
        // delete should be synced to the remote, because we set up the conflict handler to
        // have local always win. assert that this is reflected remotely and locally.
        goOnline()
        // do one sync pass to get the local delete to happen via conflict resolution
        try ctx.streamAndSync()
        // do another sync pass to get the local delete resolution committed to the remote
        try ctx.streamAndSync()

        // make sure that a conflict was raised
        XCTAssertTrue(conflictRaised)

        XCTAssertNil(coll.findOne(doc1Filter))
        XCTAssertNil(remoteColl.findOne(doc1Filter))

        coll.verifyUndoCollectionEmpty()
    }

    func testMultiUserSupport() throws {
        let (remoteColl, coll) = ctx.remoteCollAndSync

        var docToInsertUser1 = ["hello": "world"] as Document
        var docToInsertUser2 = ["hola": "mundo"] as Document
        var docToInsertUser3 = ["hallo": "welt"] as Document

        // configure Sync
        coll.configure(conflictHandler: failingConflictHandler)

        let doc1Id = coll.insertOne(&docToInsertUser1)!.insertedId!
        let doc1Filter = ["_id": doc1Id] as Document

        // assert that the resolution is reflected locally, but not yet remotely
        var expectedDocument = docToInsertUser1
        XCTAssertEqual(expectedDocument.sorted(), coll.findOne(doc1Filter)!.sorted())

        // sync. assert that the resolution is reflected locally and remotely.
        try ctx.streamAndSync()

        XCTAssertEqual(expectedDocument.sorted(), coll.findOne(doc1Filter)!.sorted())
        XCTAssertEqual(docToInsertUser1.sorted(),
                       SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!.sorted()))
        SyncIntTestUtilities.assertNoVersionFieldsInLocalColl(coll: coll)

        // switch to the other user. assert that there is no locally stored docToInsertUser1
        try ctx.switchToUser(withId: userId2)
        XCTAssertNil(coll.findOne(doc1Filter))

        // sync again. since the configurations have been reset, nothing should exist locally
        try ctx.streamAndSync()
        XCTAssertNil(coll.findOne(doc1Filter))

        // assert nothing has changed remotely
        XCTAssertEqual(docToInsertUser1.sorted(),
                       SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!.sorted()))
        SyncIntTestUtilities.assertNoVersionFieldsInLocalColl(coll: coll)

        // insert a document as the second user
        let doc2Id = coll.insertOne(&docToInsertUser2)!.insertedId!
        let doc2Filter = ["_id": doc2Id] as Document

        try ctx.streamAndSync()

        expectedDocument = docToInsertUser2

        XCTAssertEqual(expectedDocument.sorted(), coll.findOne(doc2Filter)!.sorted())
        XCTAssertEqual(docToInsertUser2.sorted(),
                       SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc2Filter)!.sorted()))

        SyncIntTestUtilities.assertNoVersionFieldsInLocalColl(coll: coll)

        // switch to a third user, and assert that the local collection is now empty, both before and after syncing
        try ctx.switchToUser(withId: userId3)
        XCTAssertNil(coll.findOne(doc1Filter))
        XCTAssertNil(coll.findOne(doc2Filter))

        try ctx.streamAndSync()
        XCTAssertNil(coll.findOne(doc1Filter))
        XCTAssertNil(coll.findOne(doc2Filter))

        // assert nothing has changed remotely
        XCTAssertEqual(docToInsertUser1.sorted(),
                       SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc1Filter)!.sorted()))
        XCTAssertEqual(docToInsertUser2.sorted(),
                       SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc2Filter)!.sorted()))

        // insert a document as the third user
        let doc3Id = coll.insertOne(&docToInsertUser3)!.insertedId!
        let doc3Filter = ["_id": doc3Id] as Document

        try ctx.streamAndSync()

        expectedDocument = docToInsertUser3

        XCTAssertEqual(expectedDocument.sorted(), coll.findOne(doc3Filter)!.sorted())
        XCTAssertEqual(docToInsertUser3.sorted(),
                       SyncIntTestUtilities.withoutSyncVersion(remoteColl.findOne(doc3Filter)!.sorted()))

        SyncIntTestUtilities.assertNoVersionFieldsInLocalColl(coll: coll)

        // switch back to the other users and assert that the docs are still intact
        try ctx.switchToUser(withId: userId1)
        XCTAssertEqual(docToInsertUser1.sorted(), coll.findOne(doc1Filter)!.sorted())
        XCTAssertNil(coll.findOne(doc2Filter))
        XCTAssertNil(coll.findOne(doc3Filter))

        try ctx.switchToUser(withId: userId2)
        XCTAssertNil(coll.findOne(doc1Filter))
        XCTAssertEqual(docToInsertUser2.sorted(), coll.findOne(doc2Filter)!.sorted())
        XCTAssertNil(coll.findOne(doc3Filter))

        // remove user 2 and log back in, asserting that removing the user destroyed the local collection
        try ctx.removeUser(withId: userId2)
        try ctx.reloginUser2()

        XCTAssertNil(coll.findOne(doc1Filter))
        XCTAssertNil(coll.findOne(doc2Filter))
        XCTAssertNil(coll.findOne(doc3Filter))
    }
}
