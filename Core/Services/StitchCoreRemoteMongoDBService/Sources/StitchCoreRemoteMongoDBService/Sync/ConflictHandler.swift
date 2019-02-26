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

public final class DefaultConflictHandler<T: Codable>: ConflictHandler {
    public typealias DocumentT = T
    private let remoteShouldWin: Bool

    private init(remoteShouldWin: Bool) {
        self.remoteShouldWin = remoteShouldWin
    }

    public func resolveConflict(documentId: BSONValue,
                                localEvent: ChangeEvent<T>,
                                remoteEvent: ChangeEvent<T>) throws -> T? {
        if remoteShouldWin {
            return remoteEvent.fullDocument
        }

        return localEvent.fullDocument
    }

    public static func remoteWins<T>() -> DefaultConflictHandler<T> {
        return DefaultConflictHandler<T>(remoteShouldWin: true)
    }

    public static func remoteWins<T: Codable>() -> (
        BSONValue,
        ChangeEvent<T>,
        ChangeEvent<T>) throws -> T? {
        return DefaultConflictHandler<T>(remoteShouldWin: true).resolveConflict
    }

    public static func localWins<T>() -> DefaultConflictHandler<T> {
        return DefaultConflictHandler<T>(remoteShouldWin: false)
    }

    public static func localWins<T: Codable>() -> (
        BSONValue,
        ChangeEvent<T>,
        ChangeEvent<T>) throws -> T? {
            return DefaultConflictHandler<T>(remoteShouldWin: false).resolveConflict
    }
}

internal class BlockConflictHandler<T: Codable>: ConflictHandler {
    public typealias DocumentT = T

    private let resolveConflictBlock: (
    _ documentId: BSONValue,
    _ localEvent: ChangeEvent<DocumentT>,
    _ remoteEvent: ChangeEvent<DocumentT>) throws -> DocumentT?

    init(_ resolveConflictBlock: @escaping (
        _ documentId: BSONValue,
        _ localEvent: ChangeEvent<DocumentT>,
        _ remoteEvent: ChangeEvent<DocumentT>) throws -> DocumentT?) {
        self.resolveConflictBlock = resolveConflictBlock
    }

    public func resolveConflict(
        documentId: BSONValue,
        localEvent: ChangeEvent<BlockConflictHandler.DocumentT>,
        remoteEvent: ChangeEvent<BlockConflictHandler.DocumentT>
    ) throws -> BlockConflictHandler.DocumentT? {
        return try self.resolveConflictBlock(documentId, localEvent, remoteEvent)
    }
}

internal final class AnyConflictHandler: ConflictHandler {
    private let _resolver: (BSONValue, ChangeEvent<Document>, ChangeEvent<Document>) throws -> Document?

    init<U: ConflictHandler>(_ conflictHandler: U) {
        self._resolver = { (documentId, localEvent, remoteEvent) in
            let documentT = try conflictHandler.resolveConflict(
                documentId: documentId,
                localEvent: try ChangeEvents.transform(changeEvent: localEvent),
                remoteEvent: try ChangeEvents.transform(changeEvent: remoteEvent))
            if documentT != nil {
                return try BSONEncoder().encode(documentT)
            }

            return nil
        }
    }

    func resolveConflict(documentId: BSONValue,
                         localEvent: ChangeEvent<Document>,
                         remoteEvent: ChangeEvent<Document>) throws -> Document? {
        return try self._resolver(documentId, localEvent, remoteEvent)
    }
}
