// swiftlint:disable type_body_length
// swiftlint:disable function_body_length
import Foundation
import XCTest
import MongoMobile
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

class CoreDocumentSynchronizationConfigTests: XCMongoMobileTestCase {
    private var database: ThreadSafeMongoDatabase!
    private var docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization>!

    override func setUp() {
        self.docsColl = localClient.db(namespace.databaseName)
            .collection("documents",
                        withType: CoreDocumentSynchronization.self)
        super.setUp()
    }

    override func tearDown() {
        try? self.docsColl.drop()
        super.tearDown()
    }

    func testRoundTrip() throws {
        let documentId = ObjectId()

        let coreDocSync = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                               namespace: namespace,
                                                               documentId: AnyBSONValue(documentId),
                                                               errorListener: nil)
        _ = try coreDocSync.docLock.read {
            try docsColl.insertOne(coreDocSync)
        }
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
        try coreDocSync.setSomePendingWrites(atTime: lastResolution,
                                             atVersion: lastKnownRemoteVersion,
                                             changeEvent: lastUncommittedChangeEvent)

        let encodedCoreDocSync = try coreDocSync.docLock.read { try BSONEncoder().encode(coreDocSync) }

        XCTAssertEqual(isPaused,
                       encodedCoreDocSync[CoreDocumentSynchronization.CodingKeys.isPaused.rawValue] as? Bool)
        XCTAssertEqual(isStale,
                       encodedCoreDocSync[CoreDocumentSynchronization.CodingKeys.isStale.rawValue] as? Bool)
        XCTAssertEqual(
            lastKnownRemoteVersion,
            encodedCoreDocSync[
                CoreDocumentSynchronization.CodingKeys.lastKnownRemoteVersion.rawValue
            ] as? Document
        )
        XCTAssertEqual(
            lastResolution,
            encodedCoreDocSync[CoreDocumentSynchronization.CodingKeys.lastResolution.rawValue] as? Int64)

        let lastUncommittedChangeEventBin =
            encodedCoreDocSync[
                CoreDocumentSynchronization.CodingKeys.uncommittedChangeEvent.rawValue
            ] as? Binary
        let lastUncommittedChangeEventDoc = Document.init(fromBSON: lastUncommittedChangeEventBin!.data)

        XCTAssertEqual(lastUncommittedChangeEvent,
                       try BSONDecoder().decode(ChangeEvent.self,
                                                from: lastUncommittedChangeEventDoc))

        let decodedCoreDocConfig = try BSONDecoder().decode(CoreDocumentSynchronization.self,
                                                            from: encodedCoreDocSync)

        XCTAssertEqual(isPaused, decodedCoreDocConfig.isPaused)
        XCTAssertEqual(isStale, decodedCoreDocConfig.isStale)
        XCTAssertEqual(lastKnownRemoteVersion, decodedCoreDocConfig.lastKnownRemoteVersion)
        XCTAssertEqual(lastResolution, decodedCoreDocConfig.lastResolution)
        XCTAssertEqual(lastUncommittedChangeEvent, decodedCoreDocConfig.uncommittedChangeEvent)
        XCTAssertEqual(coreDocSync, decodedCoreDocConfig)
    }

    func testSomePendingWrites() throws {
        let documentId = ObjectId()

        let coreDocSync = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                               namespace: namespace,
                                                               documentId: AnyBSONValue(documentId),
                                                               errorListener: nil)

        _ = try coreDocSync.docLock.read { try docsColl.insertOne(coreDocSync) }

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
        XCTAssertEqual(coreDocSync, try docsColl.find(["document_id": documentId]).next())

        let atVersion = DocumentVersionInfo.freshVersionDocument()
        try coreDocSync.setSomePendingWrites(atTime: 101,
                                             atVersion: atVersion,
                                             changeEvent: changeEvent)

        XCTAssertEqual(changeEvent, coreDocSync.uncommittedChangeEvent)
        XCTAssertEqual(101, coreDocSync.lastResolution)
        XCTAssertEqual(atVersion, coreDocSync.lastKnownRemoteVersion)
        XCTAssertEqual(coreDocSync, try docsColl.find(["document_id": documentId]).next())

        try coreDocSync.setPendingWritesComplete(atVersion: atVersion)
        XCTAssertNil(coreDocSync.uncommittedChangeEvent)
        XCTAssertEqual(atVersion, coreDocSync.lastKnownRemoteVersion)
        XCTAssertEqual(101, coreDocSync.lastResolution)
        XCTAssertEqual(coreDocSync, try docsColl.find(["document_id": documentId]).next())
    }

    func testCoalesceChangeEvents() {
        let documentId = ObjectId()
        var lastUncomittedChangeEvent: ChangeEvent<Document>?
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
