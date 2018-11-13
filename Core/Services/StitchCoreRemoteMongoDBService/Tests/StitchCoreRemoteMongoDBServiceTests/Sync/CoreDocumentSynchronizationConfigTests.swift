import Foundation
import XCTest
import MongoMobile
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

class CoreDocumentSynchronizationConfigTests: XCTestCase {
    private var database: MongoDatabase!
    private var client: MongoClient!
    private var docsColl: MongoCollection<CoreDocumentSynchronization.Config>!
    private var namespace = MongoNamespace.init(databaseName: ObjectId().description,
                                                collectionName: ObjectId().description)

    override func setUp() {
        try! MongoMobile.initialize()
        let path = "\(FileManager().currentDirectoryPath)/path/local_mongodb/0/"
        var isDir : ObjCBool = true
        if !FileManager().fileExists(atPath: path, isDirectory: &isDir) {
            try! FileManager().createDirectory(atPath: path, withIntermediateDirectories: true)
        }

        let settings = MongoClientSettings(
            dbPath: path
        )
        self.client = try! MongoMobile.create(settings)
        self.docsColl = try! self.client.db(namespace.databaseName)
            .collection(namespace.collectionName,
                        withType: CoreDocumentSynchronization.Config.self)
    }

    override func tearDown() {
        try? self.client.db(namespace.databaseName).drop()
        try? MongoMobile.close()
    }

    func testRoundTrip() throws {
        let documentId = ObjectId()

        var coreDocSync = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                           namespace: namespace,
                                                           documentId: AnyBSONValue(documentId))

        try! docsColl.insertOne(coreDocSync.config)

        let isPaused = true
        let isStale = true
        let lastKnownRemoteVersion = DocumentVersionInfo.getFreshVersionDocument()
        let lastResolution = 42.0

        let ceId = ["_id": documentId] as Document
        let ceFullDocument = ["foo": "bar"] as Document
        let ceDocumentKey = ceId
        let udRemovedFields = ["baz"]
        let updateDescription = UpdateDescription.init(updatedFields: ceFullDocument,
                                                       removedFields: udRemovedFields)
        let ceHasUncommittedWrites = false
        let lastUncommittedChangeEvent = ChangeEvent.init(
            id: ceId,
            operationType: .insert,
            fullDocument: ceFullDocument,
            namespace: namespace, documentKey: ceDocumentKey,
            updateDescription: updateDescription,
            hasUncommittedWrites: ceHasUncommittedWrites)

        coreDocSync.isPaused = isPaused
        coreDocSync.isStale = isStale
        coreDocSync.lastKnownRemoteVersion = lastKnownRemoteVersion
        coreDocSync.lastResolution = lastResolution
        coreDocSync.lastUncommittedChangeEvent = lastUncommittedChangeEvent

        let encodedCoreDocSync = try BSONEncoder().encode(coreDocSync.config)

        XCTAssertEqual(isPaused,
                       encodedCoreDocSync[CoreDocumentSynchronization.Config.CodingKeys.isPaused.rawValue] as? Bool)
        XCTAssertEqual(isStale,
                       encodedCoreDocSync[CoreDocumentSynchronization.Config.CodingKeys.isStale.rawValue] as? Bool)
        XCTAssertEqual(lastKnownRemoteVersion,
                       encodedCoreDocSync[CoreDocumentSynchronization.Config.CodingKeys.lastKnownRemoteVersion.rawValue] as? Document)
        XCTAssertEqual(lastResolution,
                       encodedCoreDocSync[CoreDocumentSynchronization.Config.CodingKeys.lastResolution.rawValue] as? Double)
        XCTAssertEqual(lastUncommittedChangeEvent,
                       try BSONDecoder().decode(ChangeEvent.self,
                                                from: encodedCoreDocSync[CoreDocumentSynchronization.Config.CodingKeys.lastUncommittedChangeEvent.rawValue] as! Document))

        let decodedCoreDocSync = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                                  config: try BSONDecoder().decode(CoreDocumentSynchronization.Config.self,
                                                                                                   from: encodedCoreDocSync))

        XCTAssertEqual(isPaused, decodedCoreDocSync.isPaused)
        XCTAssertEqual(isStale, decodedCoreDocSync.isStale)
        XCTAssertEqual(lastKnownRemoteVersion, decodedCoreDocSync.lastKnownRemoteVersion)
        XCTAssertEqual(lastResolution, decodedCoreDocSync.lastResolution)
        XCTAssertEqual(lastUncommittedChangeEvent, decodedCoreDocSync.lastUncommittedChangeEvent)
        XCTAssertEqual(coreDocSync, decodedCoreDocSync)
    }

    func testSomePendingWrites() throws {
        let documentId = ObjectId()

        var coreDocSync = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                           namespace: namespace,
                                                           documentId: AnyBSONValue(documentId))

        try! docsColl.insertOne(coreDocSync.config)

        let ceId = ["_id": documentId] as Document
        let ceFullDocument = ["foo": "bar"] as Document
        let ceDocumentKey = ceId
        let udRemovedFields = ["baz"]
        let updateDescription = UpdateDescription.init(updatedFields: ceFullDocument,
                                                       removedFields: udRemovedFields)
        let ceHasUncommittedWrites = false
        let changeEvent = ChangeEvent.init(
            id: ceId,
            operationType: .insert,
            fullDocument: ceFullDocument,
            namespace: namespace, documentKey: ceDocumentKey,
            updateDescription: updateDescription,
            hasUncommittedWrites: ceHasUncommittedWrites)

        coreDocSync.isPaused = true
        coreDocSync.setSomePendingWrites(atTime: 100.0, changeEvent: changeEvent)

        XCTAssertEqual(false, coreDocSync.isPaused)
        XCTAssertEqual(true, coreDocSync.isStale)
        XCTAssertEqual(changeEvent, coreDocSync.lastUncommittedChangeEvent)
        XCTAssertEqual(100.0, coreDocSync.lastResolution)
        XCTAssertEqual(coreDocSync.config, try docsColl.find(["documentId": documentId]).next())

        let atVersion = DocumentVersionInfo.getFreshVersionDocument()
        coreDocSync.setSomePendingWrites(atTime: 101.0,
                                         atVersion: atVersion,
                                         changeEvent: changeEvent)

        XCTAssertEqual(changeEvent, coreDocSync.lastUncommittedChangeEvent)
        XCTAssertEqual(101.0, coreDocSync.lastResolution)
        XCTAssertEqual(atVersion, coreDocSync.lastKnownRemoteVersion)
        XCTAssertEqual(coreDocSync.config, try docsColl.find(["documentId": documentId]).next())

        coreDocSync.setPendingWritesComplete(atVersion: atVersion)
        XCTAssertNil(coreDocSync.lastUncommittedChangeEvent)
        XCTAssertEqual(atVersion, coreDocSync.lastKnownRemoteVersion)
        XCTAssertEqual(101.0, coreDocSync.lastResolution)
        XCTAssertEqual(coreDocSync.config, try docsColl.find(["documentId": documentId]).next())
    }

    func testCoalesceChangeEvents() {
        CoreDocumentSynchronization.coalesceChangeEvents(lastUncommittedChangeEvent: <#T##ChangeEvent<Document>?#>,
                                                         newestChangeEvent: <#T##ChangeEvent<Document>#>)
    }
}
