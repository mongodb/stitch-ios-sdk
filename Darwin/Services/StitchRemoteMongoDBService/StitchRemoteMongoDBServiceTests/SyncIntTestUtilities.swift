// swiftlint:disable force_cast
import XCTest
import MongoSwift
@testable import StitchCoreRemoteMongoDBService
import StitchRemoteMongoDBService

internal class SyncIntTestUtilities {
    static internal func hasVersionField(_ document: Document) -> Bool {
        return document["__stitch_sync_version"] != nil
    }

    static internal func versionOf(_ document: Document) -> Document {
        return document["__stitch_sync_version"] as! Document
    }

    static internal func versionCounterOf(_ document: Document) -> Int64 {
        return versionOf(document)["v"] as! Int64
    }

    static internal func instanceIdOf(_ document: Document) -> String {
        return versionOf(document)["id"] as! String
    }

    static internal func appendDocumentToKey(key: String,
                                             on document: Document,
                                             documentToAppend: Document) -> Document {
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

    static internal func freshSyncVersionDoc() -> Document {
        return ["spv": 1, "id": UUID.init().uuidString, "v": 0]
    }

    static internal func withoutId(_ document: Document) -> Document {
        return document.filter { $0.key != "_id" }
    }

    static internal func withNewUnsupportedSyncVersion(_ document: Document) -> Document {
        var newDocument = document
        var badVersion = freshSyncVersionDoc()
        badVersion["spv"] = 2

        newDocument[documentVersionField] = badVersion

        return newDocument
    }

    static internal func withNewSyncVersion(_ document: Document) -> Document {
        var newDocument = document
        newDocument["__stitch_sync_version"] = freshSyncVersionDoc()
        return newDocument
    }

    static internal func withNewSyncVersionSet(_ document: Document) -> Document {
        return appendDocumentToKey(
            key: "$set",
            on: document,
            documentToAppend: [documentVersionField: freshSyncVersionDoc()])
    }

    static internal func assertNoVersionFieldsInDoc(_ doc: Document) {
        XCTAssertFalse(doc.contains(where: { $0.key == documentVersionField}))
    }

    static internal func assertNoVersionFieldsInLocalColl(coll: Sync<Document>) {
        let cursor = coll.find([:])!
        cursor.forEach { doc in
            XCTAssertNil(doc[documentVersionField])
        }
    }

    static internal func withoutSyncVersion(_ doc: Document) -> Document {
        return doc.filter { $0.key != documentVersionField }
    }
}
