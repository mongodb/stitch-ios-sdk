import MongoSwift

/// Represents possible fields that a change stream response document can have.
public struct CompactChangeEvent<DocumentType: Codable>: BaseChangeEvent {
    typealias DocumentT = DocumentType

    enum CodingKeys: String, CodingKey {
        case operationType = "ot", documentKey = "dk", updateDescription = "ud"
        case hasUncommittedWrites, stitchDocumentHash = "sdh", stitchDocumentVersion = "sdv"
        case fullDocument = "fd"
    }

    public let operationType: OperationType
    public let documentKey: Document
    public let updateDescription: UpdateDescription?
    public let hasUncommittedWrites: Bool
    public let fullDocument: DocumentType?
    /// The hash of the document
    public let stitchDocumentHash: Int64
    /// The version of the document
    public let stitchDocumentVersion: DocumentVersionInfo.Version?

    init(operationType: OperationType,
         fullDocument: DocumentT?,
         documentKey: Document,
         updateDescription: UpdateDescription?,
         hasUncommittedWrites: Bool,
         stitchDocumentHash: Int64,
         stitchDocumentVersion: DocumentVersionInfo.Version?) {
        self.operationType = operationType
        self.documentKey = documentKey
        self.updateDescription = updateDescription
        self.hasUncommittedWrites = hasUncommittedWrites
        self.stitchDocumentHash = stitchDocumentHash
        self.stitchDocumentVersion = stitchDocumentVersion
        self.fullDocument = fullDocument
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.operationType = OperationType.init(
            rawValue: try container.decode(String.self, forKey: .operationType)
            ) ?? .unknown
        self.documentKey = try container.decode(Document.self, forKey: .documentKey)
        self.updateDescription = try container.decodeIfPresent(UpdateDescription.self,
                                                               forKey: .updateDescription)
        self.hasUncommittedWrites = try container.decodeIfPresent(Bool.self,
                                                                  forKey: .hasUncommittedWrites) ?? false
        self.fullDocument = try container.decodeIfPresent(DocumentT.self, forKey: .fullDocument)
        self.stitchDocumentHash = try container.decode(Int64.self, forKey: .stitchDocumentHash)
        self.stitchDocumentVersion = try container.decodeIfPresent(DocumentVersionInfo.Version.self,
                                                                   forKey: .stitchDocumentVersion)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(operationType, forKey: .operationType)
        try container.encode(documentKey, forKey: .documentKey)
        try container.encode(updateDescription, forKey: .updateDescription)
        try container.encode(hasUncommittedWrites, forKey: .hasUncommittedWrites)
        try container.encode(fullDocument, forKey: .fullDocument)
        try container.encode(stitchDocumentHash, forKey: .stitchDocumentHash)
        try container.encodeIfPresent(stitchDocumentVersion, forKey: .stitchDocumentVersion)
    }
}
