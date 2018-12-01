import Foundation
import MongoSwift

/**
 ConflictHandler describes how to resolve a conflict between a local and remote event.
 */
public protocol ConflictHandler {
    /// The type of document involved in the conflict.
    associatedtype DocumentT: Codable

    /**
     Returns a resolution to the conflict between the given local and remote ChangeEvents.

     - parameter documentId: the document _id that has the conflict.
     - parameter localEvent: the conflicting local event.
     - parameter remoteEvent: the conflicting remote event.
     - returns: a resolution to the conflict between the given local and remote {@link ChangeEvent}s.
     */
    func resolveConflict(
        documentId: BSONValue,
        localEvent: ChangeEvent<DocumentT>,
        remoteEvent: ChangeEvent<DocumentT>) throws -> DocumentT?
}

public final class BlockConflictHandler<T: Codable>: ConflictHandler {
    public typealias DocumentT = T
    public typealias ResolveConflictBlock = (
        _ documentId: BSONValue,
        _ localEvent: ChangeEvent<DocumentT>,
        _ remoteEvent: ChangeEvent<DocumentT>) throws -> DocumentT?

    private let resolveConflictBlock: ResolveConflictBlock

    public init(_ resolveConflictBlock: @escaping ResolveConflictBlock) {
        self.resolveConflictBlock = resolveConflictBlock
    }

    public func resolveConflict(documentId: BSONValue, localEvent: ChangeEvent<BlockConflictHandler.DocumentT>, remoteEvent: ChangeEvent<BlockConflictHandler.DocumentT>) throws -> BlockConflictHandler.DocumentT? {
        return try self.resolveConflictBlock(documentId, localEvent, remoteEvent)
    }
}

internal final class AnyConflictHandler: ConflictHandler {
    private let _resolver: (BSONValue, ChangeEvent<Document>, ChangeEvent<Document>) throws -> Document?

    init<U: ConflictHandler>(_ conflictHandler: U) {
        self._resolver = { (documentId, localEvent, remoteEvent) in
            let documentT = try conflictHandler.resolveConflict(
                documentId: documentId,
                localEvent: try ChangeEvent<U.DocumentT>.transform(changeEvent: localEvent),
                remoteEvent: try ChangeEvent<U.DocumentT>.transform(changeEvent: remoteEvent))
            return try BSONEncoder().encode(documentT)
        }
    }

    func resolveConflict(documentId: BSONValue,
                         localEvent: ChangeEvent<Document>,
                         remoteEvent: ChangeEvent<Document>) throws -> Document? {
        return try self._resolver(documentId, localEvent, remoteEvent)
    }
}
