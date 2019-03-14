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

private extension Document {
    func sorted() -> Document {
        return self.sorted { (doc1, doc2) -> Bool in
            doc1.key < doc2.key
            }.reduce(into: Document()) { (doc, kvp) in
                doc[kvp.key] = kvp.value
        }
    }
}

private extension RemoteMongoCollection {
    func count(_ filter: Document) -> Int? {
        let joiner = CallbackJoiner()
        self.count(filter, joiner.capture())
        return joiner.value(asType: Int.self)
    }

    func find(_ filter: Document) -> [T]? {
        let joiner = CallbackJoiner()
        let readOp = self.find(filter, options: nil)
        readOp.toArray(joiner.capture())
        return joiner.value(asType: [T].self)
    }

    func findOne(_ filter: Document) -> Document? {
        let joiner = CallbackJoiner()
        self.findOne(filter, options: nil, joiner.capture())
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

// These extensions make the CRUD commands synchronous to simplify writing tests.
// These extensions should not be used outside of a testing environment.
private extension Sync where DocumentT == Document {
    func verifyUndoCollectionEmpty() {
        guard try! self.proxy.dataSynchronizer.undoCollection(for: self.proxy.namespace).count() == 0 else {
            XCTFail("CRUD operation leaked documents in undo collection, add breakpoint here and check stack trace")
            return
        }
    }

    func count(_ filter: Document) -> Int? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.count(filter: filter, options: nil, joiner.capture())
        return joiner.value(asType: Int.self)
    }

    func aggregate(_ pipeline: [Document]) -> MongoCursor<Document>? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.aggregate(pipeline: pipeline, options: nil, joiner.capture())
        return joiner.value(asType: MongoCursor<Document>.self)
    }

    func find(_ filter: Document) -> MongoCursor<Document>? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.find(filter: filter, joiner.capture())
        return joiner.value(asType: MongoCursor<Document>.self)
    }

    func findOne(_ filter: Document) -> Document? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.find(filter: filter, joiner.capture())
        return joiner.value(asType: MongoCursor<Document>.self)?.next()
    }

    func updateOne(filter: Document, update: Document) -> SyncUpdateResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.updateOne(filter: filter, update: update, options: nil, joiner.capture())
        return joiner.value()
    }

    func updateMany(filter: Document, update: Document, options: SyncUpdateOptions? = nil) -> SyncUpdateResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.updateMany(filter: filter, update: update, options: options, joiner.capture())
        return joiner.value()
    }

    @discardableResult
    func insertOne(_ document: inout DocumentT) -> SyncInsertOneResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.insertOne(document: document, joiner.capture())
        guard let result: SyncInsertOneResult = joiner.value() else {
            return nil
        }

        document["_id"] = result.insertedId
        return result
    }

    @discardableResult
    func insertMany(_ documents: inout [DocumentT]) -> SyncInsertManyResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.insertMany(documents: documents, joiner.capture())
        guard let result: SyncInsertManyResult = joiner.value() else {
            return nil
        }

        result.insertedIds.forEach {
            documents[$0.key]["_id"] = $0.value
        }

        return result
    }

    func deleteOne(_ filter: Document) -> SyncDeleteResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.deleteOne(filter: filter, joiner.capture())
        return joiner.value()
    }

    func deleteMany(_ filter: Document) -> SyncDeleteResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.deleteMany(filter: filter, joiner.capture())
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
    let stitchClient: StitchAppClient
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

    init(stitchClient: StitchAppClient,
         mongoClient: RemoteMongoClient,
         networkMonitor: NetworkMonitor,
         dbName: String,
         collName: String) {
        self.stitchClient = stitchClient
        self.mongoClient = mongoClient
        self.networkMonitor = networkMonitor
        self.dbName = dbName
        self.collName = collName
    }

    func streamAndSync() throws {
        let (_, coll) = remoteCollAndSync
        if networkMonitor.state == .connected {
            if let iCSDel = coll.proxy
                .dataSynchronizer
                .instanceChangeStreamDelegate,
                let nsConfig = iCSDel[MongoNamespace(databaseName: dbName, collectionName: collName)] {
                nsConfig.add(streamDelegate: streamJoiner)
                streamJoiner.streamState = nsConfig.state
                if nsConfig.state == .closed {
                    iCSDel.start()
                }

                streamJoiner.wait(forState: .open)
            }

        }
        _ = try coll.proxy.dataSynchronizer.doSyncPass()
    }

    func watch(forEvents count: Int) throws {
        streamJoiner.wait(forEvents: count)
    }

    func powerCycleDevice() throws {
        try remoteCollAndSync.1.proxy.dataSynchronizer.reloadConfig()
        if streamJoiner.streamState != nil {
            streamJoiner.wait(forState: .closed)
        }
    }

    func teardown() {
        let (_, coll) = remoteCollAndSync
        coll.proxy
            .dataSynchronizer
            .instanceChangeStreamDelegate.stop()
    }
}

class SyncPerfTests: BaseStitchIntTestCocoaTouch {
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
        //        ctx.streamJoiner.wait(forState: .open)
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
        try sync.sync(ids: [doc1Id])
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
                       withoutSyncVersion(remoteFindResult ?? [:]))

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

        sync.verifyUndoCollectionEmpty()
    }

    // MARK: Utilities

    private func hasVersionField(_ document: Document) -> Bool {
        return document["__stitch_sync_version"] != nil
    }

    private func versionOf(_ document: Document) -> Document {
        return document["__stitch_sync_version"] as! Document
    }

    private func versionCounterOf(_ document: Document) -> Int64 {
        return versionOf(document)["v"] as! Int64
    }

    private func instanceIdOf(_ document: Document) -> String {
        return versionOf(document)["id"] as! String
    }

    private func appendDocumentToKey(key: String, on document: Document, documentToAppend: Document) -> Document {
        var document = document
        if let value = document[key] as? Document {
            var values = value.map { ($0.key, $0.value) }
            values.append(contentsOf: documentToAppend.map { ($0.key, $0.value) })
            document[key] = values.reduce(into: Document()) { (doc, kvp) in
                doc[kvp.0] = kvp.1
            }
        } else {
            document[key] = documentToAppend
        }

        return document
    }

    private func freshSyncVersionDoc() -> Document {
        return ["spv": 1, "id": UUID.init().uuidString, "v": 0]
    }

    private func withoutId(_ document: Document) -> Document {
        return document.filter { $0.key != "_id" }
    }

    private func withNewUnsupportedSyncVersion(_ document: Document) -> Document {
        var newDocument = document
        var badVersion = freshSyncVersionDoc()
        badVersion["spv"] = 2

        newDocument[documentVersionField] = badVersion

        return newDocument
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

    private func assertNoVersionFieldsInDoc(_ doc: Document) {
        XCTAssertFalse(doc.contains(where: { $0.key == documentVersionField}))
    }

    private func assertNoVersionFieldsInLocalColl(coll: Sync<Document>) {
        let cursor = coll.find([:])!
        cursor.forEach { doc in
            XCTAssertNil(doc[documentVersionField])
        }
    }
}
