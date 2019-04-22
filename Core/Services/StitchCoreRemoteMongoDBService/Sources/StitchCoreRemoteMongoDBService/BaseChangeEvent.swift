import MongoSwift

/// The type of operation that occurred within a ChangeEvent.
public enum OperationType: String, Codable {
    case insert, delete, replace, update, unknown
}

/// Base change event for either Compact or Full ChangeEvents.
protocol BaseChangeEvent: Codable, Hashable {
    associatedtype DocumentT: Codable

    /// The type of operation that occurred
    var operationType: OperationType { get }
    /**
     The ObjectID of the document created or modified by the
     insert, replace, delete, update operations (i.e. CRUD operations).
     */
    var documentKey: Document { get }
    /**
     A document describing the fields that were updated or removed by
     the update operation.
     */
    var updateDescription: UpdateDescription? { get }
    /// Whether or not this ChangeEvent has pending writes.
    var hasUncommittedWrites: Bool { get }
    /**
     The document created or modified by the insert, replace, delete,
     update operations (i.e. CRUD operations).

     For insert and replace operations, this represents the new document
     created by the operation.

     For delete operations, this field is omitted as the document no
     longer exists.

     For update operations, this field represents the most current
     majority-committed version of the document modified by the update
     operation. This document may differ from the changes described in
     updateDescription if other majority-committed operations modified
     the document between the original update operation and the full
     document lookup.
     */
    var fullDocument: DocumentT? { get }
}

extension BaseChangeEvent {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(AnyBSONValue(documentKey))
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.documentKey.bsonEquals(rhs.documentKey) &&
            lhs.operationType == rhs.operationType &&
            lhs.hasUncommittedWrites == rhs.hasUncommittedWrites
    }
}
