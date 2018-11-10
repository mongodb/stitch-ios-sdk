import MongoSwift

public struct ChangeEvent<DocumentT: Codable>: Codable {
    public enum OperationType: String, Codable {
        case insert, delete, replace, update, unknown
    }

    public let id: Document // Metadata related to the operation (the resumeToken).
    public let operationType: OperationType
    public let fullDocument: DocumentT
    public let ns: MongoNamespace
    public let documentKey: Document
    public let updateDescription: UpdateDescription
    public let hasUncommittedWrites: Bool
}
