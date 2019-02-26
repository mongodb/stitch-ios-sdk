import Foundation
import MongoSwift

/**
 * Utility functions for generating change events from local changes.
 */
internal class ChangeEvents {
    /**
     Transform a ChangeEvent of type Document to type T.

     - parameter changeEvent: the ChangeEvent to transform
     - returns: a ChangeEvent where the fullDocument is of type T
     */
    static func transform<T: Codable>(changeEvent: ChangeEvent<Document>) throws -> ChangeEvent<T> {
        var fullDocument: T?
        if let actualFullDocument = changeEvent.fullDocument {
            fullDocument = try BSONDecoder().decode(T.self, from: DataSynchronizer.sanitizeDocument(actualFullDocument))
        }
        return ChangeEvent<T>.init(
            id: changeEvent.id,
            operationType: changeEvent.operationType,
            fullDocument: fullDocument,
            ns: changeEvent.ns,
            documentKey: changeEvent.documentKey,
            updateDescription: changeEvent.updateDescription,
            hasUncommittedWrites: changeEvent.hasUncommittedWrites)
    }

    /**
     Generates a change event for a local insert of the given document in the given namespace.

     - parameter namespace: the namespace where the document was inserted.
     - parameter document: the document that was inserted.
     - returns a change event for a local insert of the given document in the given namespace.
     */
    static func changeEventForLocalInsert(namespace: MongoNamespace,
                                          document: Document,
                                          documentId: BSONValue,
                                          writePending: Bool) -> ChangeEvent<Document> {
        return ChangeEvent<Document>.init(
            id: AnyBSONValue(Document()),
            operationType: .insert,
            fullDocument: document,
            ns: namespace,
            documentKey: ["_id": documentId],
            updateDescription: nil,
            hasUncommittedWrites: writePending)
    }

    /**
     Generates a change event for a local update of a document in the given namespace referring
     to the given document _id.

     - parameter namespace: the namespace where the document was updated.
     - parameter documentId: the _id of the document that was updated.
     - parameter update: the update specifier.
     - returns: a change event for a local update of a document in the given namespace referring
     to the given document _id.
     */
    static func changeEventForLocalUpdate(namespace: MongoNamespace,
                                          documentId: BSONValue,
                                          update: UpdateDescription,
                                          fullDocumentAfterUpdate: Document,
                                          writePending: Bool) -> ChangeEvent<Document> {
        return ChangeEvent<Document>(
            id: AnyBSONValue(Document()),
            operationType: .update,
            fullDocument: fullDocumentAfterUpdate,
            ns: namespace,
            documentKey: ["_id": documentId],
            updateDescription: update,
            hasUncommittedWrites: writePending)
    }

    /**
     Generates a change event for a local replacement of a document in the given namespace referring
     to the given document _id.

     - parameter namespace: the namespace where the document was replaced.
     - parameter documentId: the _id of the document that was replaced.
     - parameter document: the replacement document.
     - returns: a change event for a local replacement of a document in the given namespace referring
     to the given document _id.
     */
    static func changeEventForLocalReplace(namespace: MongoNamespace,
                                           documentId: BSONValue,
                                           document: Document,
                                           updateDescription: UpdateDescription? = nil,
                                           writePending: Bool) -> ChangeEvent<Document> {
        return ChangeEvent<Document>(
            id: AnyBSONValue(Document()),
            operationType: .replace,
            fullDocument: document,
            ns: namespace,
            documentKey: ["_id": documentId],
            updateDescription: updateDescription,
            hasUncommittedWrites: writePending)
    }

    /**
     Generates a change event for a local deletion of a document in the given namespace referring
     to the given document _id.

     - parameter namespace: the namespace where the document was deleted.
     - parameter documentId: the _id of the document that was deleted.
     - returns: a change event for a local deletion of a document in the given namespace referring
     to the given document _id.
     */
    static func changeEventForLocalDelete(namespace: MongoNamespace,
                                          documentId: BSONValue,
                                          writePending: Bool) -> ChangeEvent<Document> {
        return ChangeEvent<Document>(
            id: AnyBSONValue(Document()),
            operationType: .delete,
            fullDocument: nil,
            ns: namespace,
            documentKey: ["_id": documentId],
            updateDescription: nil,
            hasUncommittedWrites: writePending)
    }
}
