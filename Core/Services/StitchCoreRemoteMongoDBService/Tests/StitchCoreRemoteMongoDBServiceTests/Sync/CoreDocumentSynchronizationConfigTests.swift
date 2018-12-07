import Foundation
import XCTest
import MongoMobile
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

class CoreDocumentSynchronizationConfigTests: XCMongoMobileTestCase {
    private var database: MongoDatabase!
    private var docsColl: MongoCollection<CoreDocumentSynchronization.Config>!

    override func setUp() {
        self.docsColl = try! localClient.db(namespace.databaseName)
            .collection("documents",
                        withType: CoreDocumentSynchronization.Config.self)
    }

    func testRoundTrip() throws {
        let documentId = ObjectId()

        var coreDocSync = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                           namespace: namespace,
                                                           documentId: AnyBSONValue(documentId),
                                                           errorListener: nil)

        try! docsColl.insertOne(coreDocSync.config)

        let isPaused = true
        let isStale = true
        let lastKnownRemoteVersion = DocumentVersionInfo.freshVersionDocument()

        let lastResolution: Int64 = 42

        let ceId = ["_id": documentId] as Document
        let ceFullDocument = ["foo": "bar"] as Document
        let ceDocumentKey = ceId
        let udRemovedFields = ["baz"]
        let updateDescription = UpdateDescription.init(updatedFields: ceFullDocument,
                                                       removedFields: udRemovedFields)
        let ceHasUncommittedWrites = false
        let lastUncommittedChangeEvent = ChangeEvent.init(
            id: AnyBSONValue(ceId),
            operationType: .insert,
            fullDocument: ceFullDocument,
            ns: namespace, documentKey: ceDocumentKey,
            updateDescription: updateDescription,
            hasUncommittedWrites: ceHasUncommittedWrites)

        coreDocSync.isPaused = isPaused
        coreDocSync.isStale = isStale
        coreDocSync.lastKnownRemoteVersion = lastKnownRemoteVersion
        coreDocSync.lastResolution = lastResolution
        coreDocSync.uncommittedChangeEvent = lastUncommittedChangeEvent

        let encodedCoreDocSync = try BSONEncoder().encode(coreDocSync.config)

        print(encodedCoreDocSync)
        XCTAssertEqual(isPaused,
                       encodedCoreDocSync[CoreDocumentSynchronization.Config.CodingKeys.isPaused.rawValue] as? Bool)
        XCTAssertEqual(isStale,
                       encodedCoreDocSync[CoreDocumentSynchronization.Config.CodingKeys.isStale.rawValue] as? Bool)
        XCTAssertEqual(lastKnownRemoteVersion,
                       encodedCoreDocSync[CoreDocumentSynchronization.Config.CodingKeys.lastKnownRemoteVersion.rawValue] as? Document)
        XCTAssertEqual(lastResolution,
                       encodedCoreDocSync[CoreDocumentSynchronization.Config.CodingKeys.lastResolution.rawValue] as? Int64)
        XCTAssertEqual(lastUncommittedChangeEvent,
                       try BSONDecoder().decode(ChangeEvent.self,
                                                from: encodedCoreDocSync[CoreDocumentSynchronization.Config.CodingKeys.uncommittedChangeEvent.rawValue] as! Document))

        var decodedCoreDocConfig = try BSONDecoder().decode(CoreDocumentSynchronization.Config.self,
                                                            from: encodedCoreDocSync)
        let decodedCoreDocSync = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                                  config: &decodedCoreDocConfig,
                                                                  errorListener: nil)

        XCTAssertEqual(isPaused, decodedCoreDocSync.isPaused)
        XCTAssertEqual(isStale, decodedCoreDocSync.isStale)
        XCTAssertEqual(lastKnownRemoteVersion, decodedCoreDocSync.lastKnownRemoteVersion)
        XCTAssertEqual(lastResolution, decodedCoreDocSync.lastResolution)
        XCTAssertEqual(lastUncommittedChangeEvent, decodedCoreDocSync.uncommittedChangeEvent)
        XCTAssertEqual(coreDocSync, decodedCoreDocSync)
    }

    func testSomePendingWrites() throws {
        let documentId = ObjectId()

        var coreDocSync = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                           namespace: namespace,
                                                           documentId: AnyBSONValue(documentId),
                                                           errorListener: nil)

        try! docsColl.insertOne(coreDocSync.config)

        let ceId = ["_id": documentId] as Document
        let ceFullDocument = ["foo": "bar"] as Document
        let ceDocumentKey = ceId
        let udRemovedFields = ["baz"]
        let updateDescription = UpdateDescription.init(updatedFields: ceFullDocument,
                                                       removedFields: udRemovedFields)
        let ceHasUncommittedWrites = false
        let changeEvent = ChangeEvent.init(
            id: AnyBSONValue(ceId),
            operationType: .insert,
            fullDocument: ceFullDocument,
            ns: namespace, documentKey: ceDocumentKey,
            updateDescription: updateDescription,
            hasUncommittedWrites: ceHasUncommittedWrites)

        coreDocSync.isPaused = true
        try coreDocSync.setSomePendingWrites(atTime: 100, changeEvent: changeEvent)

        XCTAssertEqual(false, coreDocSync.isPaused)
        XCTAssertEqual(true, coreDocSync.isStale)
        XCTAssertEqual(changeEvent, coreDocSync.uncommittedChangeEvent)
        XCTAssertEqual(100, coreDocSync.lastResolution)
        XCTAssertEqual(coreDocSync.config, try docsColl.find(["documentId": documentId]).next())

        let atVersion = DocumentVersionInfo.freshVersionDocument()
        try coreDocSync.setSomePendingWrites(atTime: 101,
                                             atVersion: atVersion,
                                             changeEvent: changeEvent)

        XCTAssertEqual(changeEvent, coreDocSync.uncommittedChangeEvent)
        XCTAssertEqual(101, coreDocSync.lastResolution)
        XCTAssertEqual(atVersion, coreDocSync.lastKnownRemoteVersion)
        XCTAssertEqual(coreDocSync.config, try docsColl.find(["documentId": documentId]).next())

        try coreDocSync.setPendingWritesComplete(atVersion: atVersion)
        XCTAssertNil(coreDocSync.uncommittedChangeEvent)
        XCTAssertEqual(atVersion, coreDocSync.lastKnownRemoteVersion)
        XCTAssertEqual(101, coreDocSync.lastResolution)
        XCTAssertEqual(coreDocSync.config, try docsColl.find(["documentId": documentId]).next())
    }

    func testCoalesceChangeEvents() {
        let documentId = ObjectId()
        var lastUncomittedChangeEvent: ChangeEvent<Document>? = nil
        var newestChangeEvent = ChangeEvent<Document>.changeEventForLocalUpdate(
            namespace: namespace,
            documentId: documentId,
            update: UpdateDescription.init(updatedFields: ["foo": "bar"] as Document,
                                           removedFields: ["baz"]),
            fullDocumentAfterUpdate: ["foo": "bar"],
            writePending: false)

        // nil lastUncomittedChangeEvent
        var coalesceResult = CoreDocumentSynchronization.coalesceChangeEvents(
            lastUncommittedChangeEvent: lastUncomittedChangeEvent,
            newestChangeEvent: newestChangeEvent)
        XCTAssertEqual(newestChangeEvent, coalesceResult)

        lastUncomittedChangeEvent = ChangeEvent<Document>.changeEventForLocalInsert(namespace: namespace,
                                                                                    document: ["foo": "qux"],
                                                                                    writePending: true)

        // insert -> update should equal insert
        coalesceResult = CoreDocumentSynchronization.coalesceChangeEvents(
            lastUncommittedChangeEvent: lastUncomittedChangeEvent,
            newestChangeEvent: newestChangeEvent)
        XCTAssertEqual(ChangeEvent<Document>(
            id: newestChangeEvent.id,
            operationType: .insert,
            fullDocument: newestChangeEvent.fullDocument,
            ns: newestChangeEvent.ns,
            documentKey: newestChangeEvent.documentKey,
            updateDescription: nil,
            hasUncommittedWrites: newestChangeEvent.hasUncommittedWrites), coalesceResult)

        newestChangeEvent = ChangeEvent<Document>.changeEventForLocalReplace(
            namespace: namespace,
            documentId: documentId,
            document: ["foo": "bar"],
            writePending: true)

        // insert -> replace should equal insert
        coalesceResult = CoreDocumentSynchronization.coalesceChangeEvents(
            lastUncommittedChangeEvent: lastUncomittedChangeEvent,
            newestChangeEvent: newestChangeEvent)
        XCTAssertEqual(ChangeEvent<Document>(
            id: newestChangeEvent.id,
            operationType: .insert,
            fullDocument: newestChangeEvent.fullDocument,
            ns: newestChangeEvent.ns,
            documentKey: newestChangeEvent.documentKey,
            updateDescription: nil,
            hasUncommittedWrites: newestChangeEvent.hasUncommittedWrites), coalesceResult)

        newestChangeEvent = ChangeEvent<Document>.changeEventForLocalDelete(namespace: namespace,
                                                                            documentId: documentId,
                                                                            writePending: false)

        // insert -> delete should default to the newestChangeEvent
        coalesceResult = CoreDocumentSynchronization.coalesceChangeEvents(
            lastUncommittedChangeEvent: lastUncomittedChangeEvent,
            newestChangeEvent: newestChangeEvent)
        XCTAssertEqual(newestChangeEvent, coalesceResult)

        newestChangeEvent = ChangeEvent<Document>.changeEventForLocalInsert(
            namespace: namespace,
            document: ["foo": "bar"] as Document,
            writePending: false)

        // insert -> insert should default to the newestChangeEvent
        coalesceResult = CoreDocumentSynchronization.coalesceChangeEvents(
            lastUncommittedChangeEvent: lastUncomittedChangeEvent,
            newestChangeEvent: newestChangeEvent)
        XCTAssertEqual(newestChangeEvent, coalesceResult)

        lastUncomittedChangeEvent = ChangeEvent<Document>.changeEventForLocalDelete(
            namespace: namespace,
            documentId: documentId,
            writePending: false)

        // delete -> insert should equal replace
        coalesceResult = CoreDocumentSynchronization.coalesceChangeEvents(
            lastUncommittedChangeEvent: lastUncomittedChangeEvent,
            newestChangeEvent: newestChangeEvent)
        XCTAssertEqual(ChangeEvent(
            id: newestChangeEvent.id,
            operationType: .replace,
            fullDocument: newestChangeEvent.fullDocument,
            ns: newestChangeEvent.ns,
            documentKey: newestChangeEvent.documentKey,
            updateDescription: nil,
            hasUncommittedWrites: newestChangeEvent.hasUncommittedWrites), coalesceResult)

        newestChangeEvent = ChangeEvent<Document>.changeEventForLocalUpdate(
            namespace: namespace,
            documentId: documentId,
            update: UpdateDescription.init(updatedFields: ["foo": "bar"] as Document,
                                           removedFields: ["baz"]),
            fullDocumentAfterUpdate: ["foo": "bar"],
            writePending: false)

        // delete -> update should default to newestChangeEvent
        coalesceResult = CoreDocumentSynchronization.coalesceChangeEvents(
            lastUncommittedChangeEvent: lastUncomittedChangeEvent,
            newestChangeEvent: newestChangeEvent)
        XCTAssertEqual(newestChangeEvent, coalesceResult)

        newestChangeEvent = ChangeEvent<Document>.changeEventForLocalDelete(
            namespace: namespace,
            documentId: documentId,
            writePending: false)

        // delete -> delete should default to newestChangeEvent
        coalesceResult = CoreDocumentSynchronization.coalesceChangeEvents(
            lastUncommittedChangeEvent: lastUncomittedChangeEvent,
            newestChangeEvent: newestChangeEvent)
        XCTAssertEqual(newestChangeEvent, coalesceResult)

        newestChangeEvent = ChangeEvent<Document>.changeEventForLocalReplace(
            namespace: namespace,
            documentId: documentId,
            document: ["foo": "bar"],
            writePending: true)

        // delete -> replace should default to newestChangeEvent
        coalesceResult = CoreDocumentSynchronization.coalesceChangeEvents(
            lastUncommittedChangeEvent: lastUncomittedChangeEvent,
            newestChangeEvent: newestChangeEvent)
        XCTAssertEqual(newestChangeEvent, coalesceResult)
    }
}
