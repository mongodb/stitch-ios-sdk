import MongoSwift

/// The type of operation that occurred within a ChangeEvent.
public enum OperationType: String, Codable {
    case insert, delete, replace, update, unknown
}

/// Represents possible fields that a change stream response document can have.
public struct ChangeEvent<DocumentT: Codable>: Codable, Hashable {
    enum CodingKeys: String, CodingKey {
        case id = "_id", operationType, fullDocument, ns
        case documentKey, updateDescription, hasUncommittedWrites
    }

    /// Metadata related to the operation.
    public let id: AnyBSONValue
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
    public let fullDocument: DocumentT?
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

    init(id: AnyBSONValue,
         operationType: OperationType,
         fullDocument: DocumentT?,
         ns: MongoNamespace,
         documentKey: Document,
         updateDescription: UpdateDescription?,
         hasUncommittedWrites: Bool) {
        self.id = id
        self.operationType = operationType
        self.fullDocument = fullDocument
        self.ns = ns
        self.documentKey = documentKey
        self.updateDescription = updateDescription
        self.hasUncommittedWrites = hasUncommittedWrites
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(AnyBSONValue.self, forKey: .id)
        self.operationType = OperationType.init(
            rawValue: try container.decode(String.self, forKey: .operationType)
        ) ?? .unknown
        self.fullDocument = try container.decodeIfPresent(DocumentT.self, forKey: .fullDocument)
        self.ns = try container.decode(MongoNamespace.self, forKey: .ns)
        self.documentKey = try container.decode(Document.self, forKey: .documentKey)
        self.updateDescription = try container.decodeIfPresent(UpdateDescription.self, forKey: .updateDescription)
        self.hasUncommittedWrites = try container.decodeIfPresent(Bool.self, forKey: .hasUncommittedWrites) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(operationType, forKey: .operationType)
        try container.encode(fullDocument, forKey: .fullDocument)
        try container.encode(ns, forKey: .ns)
        try container.encode(documentKey, forKey: .documentKey)
        try container.encode(updateDescription, forKey: .updateDescription)
        try container.encode(hasUncommittedWrites, forKey: .hasUncommittedWrites)
    }

    public static func == (lhs: ChangeEvent<DocumentT>, rhs: ChangeEvent<DocumentT>) -> Bool {
        return bsonEquals(lhs.id.value, rhs.id.value)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
