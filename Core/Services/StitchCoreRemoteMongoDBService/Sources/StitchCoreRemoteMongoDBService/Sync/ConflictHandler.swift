import Foundation
import MongoSwift

/**
 * ConflictHandler describes how to resolve a conflict between a local and remote event.
 * - parameter DocumentT: the type of document involved in the conflict.
 */
public protocol ConflictHandler {
    associatedtype DocumentT: Codable

    /**
     * Returns a resolution to the conflict between the given local and remote {@link ChangeEvent}s.
     *
     * - parameter documentId: the document _id that has the conflict.
     * - parameter localEvent: the conflicting local event.
     * - parameter remoteEvent: the conflicting remote event.
     * - returns: a resolution to the conflict between the given local and remote {@link ChangeEvent}s.
     */
    func resolveConflict(
        documentId: BSONValue,
        localEvent: ChangeEvent<DocumentT>,
        remoteEvent: ChangeEvent<DocumentT>) -> DocumentT
}

internal final class AnyConflictHandler: ConflictHandler {
    private let _resolver: (BSONValue, ChangeEvent<Document>, ChangeEvent<Document>) -> Document

    init<U: ConflictHandler>(_ conflictHandler: U) {
        self._resolver = { (documentId, localEvent, remoteEvent) in
            let documentT = conflictHandler.resolveConflict(
                documentId: documentId,
                localEvent: ChangeEvent<U.DocumentT>.transform(changeEvent: localEvent),
                remoteEvent: ChangeEvent<U.DocumentT>.transform(changeEvent: remoteEvent))
            return try! BSONEncoder().encode(documentT)
        }
    }

    func resolveConflict(documentId: BSONValue,
                         localEvent: ChangeEvent<Document>,
                         remoteEvent: ChangeEvent<Document>) -> Document {
        return self._resolver(documentId, localEvent, remoteEvent)
    }
}
