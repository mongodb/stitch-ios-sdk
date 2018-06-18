import Foundation
import MongoSwift

/// The result of an `updateOne` or `updateMany` operation a `RemoteMongoCollection`.
public struct RemoteUpdateResult: Decodable {
    /// The number of documents that matched the filter.
    public let matchedCount: Int
    
    /// The number of documents modified.
    public let modifiedCount: Int
    
    /// The identifier of the inserted document if an upsert took place.
    public let upsertedId: BsonValue?
    
    internal init(matchedCount: Int, modifiedCount: Int, upsertedId: BsonValue?) {
        self.matchedCount = matchedCount
        self.modifiedCount = modifiedCount
        self.upsertedId = upsertedId
    }
    
    // Workaround until SWIFT-104 is merged, which will make BsonValue `Decodable`
    /// :nodoc:
    public init(from decoder: Decoder) throws {
        let document = try decoder.singleValueContainer().decode(Document.self)
        guard let matched = document[CodingKeys.matchedCount.rawValue] as? Int,
              let modified = document[CodingKeys.modifiedCount.rawValue] as? Int else {
            throw MongoError.invalidResponse()
        }
        self.matchedCount = matched
        self.modifiedCount = modified
        self.upsertedId = document[CodingKeys.upsertedId.rawValue]
    }
    
    internal enum CodingKeys: String, CodingKey {
        case matchedCount, modifiedCount, upsertedId
    }
}
