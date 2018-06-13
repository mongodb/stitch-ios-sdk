import Foundation
import MongoSwift

/// The result of an `updateOne` or `updateMany` operation a `RemoteMongoCollection`.
public struct RemoteUpdateResult: Decodable {
    /// The number of documents that matched the filter.
    public let matchedCount: Int
    
    /// The identifier of the inserted document if an upsert took place.
    public let upsertedId: BsonValue?
    
    internal init(matchedCount: Int, upsertedId: BsonValue?) {
        self.matchedCount = matchedCount
        self.upsertedId = upsertedId
    }
    
    // Workaround until SWIFT-104 is merged, which will make BsonValue `Decodable`
    public init(from decoder: Decoder) throws {
        let document = try decoder.singleValueContainer().decode(Document.self)
        guard let matched = document[CodingKeys.matchedCount.rawValue] as? Int else {
            throw MongoError.invalidResponse()
        }
        self.matchedCount = matched
        self.upsertedId = document[CodingKeys.upsertedId.rawValue]
    }
    
    internal enum CodingKeys: String, CodingKey {
        case matchedCount, upsertedId
    }
}
