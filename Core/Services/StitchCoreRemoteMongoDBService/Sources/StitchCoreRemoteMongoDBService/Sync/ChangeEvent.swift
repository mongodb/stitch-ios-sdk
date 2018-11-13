import MongoSwift

/// The type of operation that occurred within a ChangeEvent.
public enum OperationType: String, Codable {
    case insert, delete, replace, update, unknown
}

/// Represents possible fields that a change stream response document can have.
public struct ChangeEvent<DocumentT: Codable>: Codable, Hashable {
    /// Metadata related to the operation.
    public let id: Document
    /// The type of operation that occurred
    public let operationType: OperationType
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
    public let fullDocument: DocumentT
    /// The namespace (database and or collection) affected by the event.
    public let ns: MongoNamespace
    /**
     The ObjectID of the document created or modified by the
     insert, replace, delete, update operations (i.e. CRUD operations).
    */
    public let documentKey: Document
    /**
     A document describing the fields that were updated or removed by
     the update operation.
    */
    public let updateDescription: UpdateDescription?
    /// Whether or not this ChangeEvent has pending writes.
    public let hasUncommittedWrites: Bool

    public static func == (lhs: ChangeEvent<DocumentT>, rhs: ChangeEvent<DocumentT>) -> Bool {
        return bsonEquals(lhs.documentKey, rhs.documentKey)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(documentKey.canonicalExtendedJSON)
    }

    /**
     Transform a ChangeEvent of type Document to type T.

     - parameter changeEvent: the ChangeEvent to transform
     - returns: a ChangeEvent where the fullDocument is of type T
    */
    static func transform<T: Codable>(changeEvent: ChangeEvent<Document>) -> ChangeEvent<T> {
        return ChangeEvent<T>.init(
            id: changeEvent.id,
            operationType: changeEvent.operationType,
            fullDocument: try! BSONDecoder().decode(T.self,
            from: changeEvent.fullDocument),
            ns: changeEvent.ns,
            documentKey: changeEvent.documentKey,
            updateDescription: changeEvent.updateDescription,
            hasUncommittedWrites: changeEvent.hasUncommittedWrites)
    }

    /**
     * Generates a change event for a local insert of the given document in the given namespace.
     *
     * @param namespace the namespace where the document was inserted.
     * @param document the document that was inserted.
     * @return a change event for a local insert of the given document in the given namespace.
     */
    static func changeEventForLocalInsert(namespace: MongoNamespace,
                                          document: Document,
                                          writePending: Bool) -> ChangeEvent<Document> {
        let docId = document["_id"]
        return ChangeEvent(
            Document(),
        ChangeEvent.OperationType.INSERT,
        document,
        namespace,
        new BsonDocument("_id", docId),
        null,
        writePending)
    }
}
