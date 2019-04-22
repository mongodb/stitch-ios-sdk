import MongoSwift

/// Represents possible fields that a change stream response document can have.
public struct ChangeEvent<DocumentType: Codable>: BaseChangeEvent {
    typealias DocumentT = DocumentType

    enum CodingKeys: String, CodingKey {
        case id = "_id", operationType, fullDocument, ns
        case documentKey, updateDescription, hasUncommittedWrites
    }

    /// Metadata related to the operation.
    public let id: AnyBSONValue
    public let operationType: OperationType
    public let fullDocument: DocumentType?
    /// The namespace (database and or collection) affected by the event.
    public let ns: MongoNamespace
    public let documentKey: Document
    public let updateDescription: UpdateDescription?
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
}
