import Foundation
import MongoSwift

/// The result of an `updateOne` or `updateMany` operation a `RemoteMongoCollection`.
public struct RemoteUpdateResult: Decodable {
    /// The number of documents that matched the filter.
    public let matchedCount: Int
    
    /// The number of documents modified.
    public let modifiedCount: Int
    
    /// The identifier of the inserted document if an upsert took place.
    public let upsertedId: ObjectId?
    
    internal init(matchedCount: Int, modifiedCount: Int, upsertedId: ObjectId?) {
        self.matchedCount = matchedCount
        self.modifiedCount = modifiedCount
        self.upsertedId = upsertedId
    }
}
