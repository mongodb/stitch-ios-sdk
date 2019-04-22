import Foundation
import MongoSwift

/// The result of an `updateOne` or `updateMany` operation a `RemoteMongoCollection`.
public struct RemoteUpdateResult: Decodable {
    /// The number of documents that matched the filter.
    public let matchedCount: Int

    /// The number of documents modified.
    public let modifiedCount: Int

    /// The identifier of the inserted document if an upsert took place.
    private let _upsertedId: AnyBSONValue?
    public var upsertedId: BSONValue? {
        return _upsertedId?.value
    }

    internal init(matchedCount: Int, modifiedCount: Int, upsertedId: BSONValue?) {
        self.matchedCount = matchedCount
        self.modifiedCount = modifiedCount
        if let upsertedId = upsertedId {
            self._upsertedId = AnyBSONValue(upsertedId)
        } else {
            self._upsertedId = nil
        }
    }

    internal enum CodingKeys: String, CodingKey {
        // swiftlint:disable identifier_name
        case matchedCount, modifiedCount, _upsertedId = "upsertedId"
    }
}

public struct SyncUpdateResult {
    /// The number of documents that matched the filter.
    public let matchedCount: Int

    /// The number of documents modified.
    public let modifiedCount: Int

    /// The identifier of the inserted document if an upsert took place.
    public let upsertedId: BSONValue?

    internal init(matchedCount: Int, modifiedCount: Int, upsertedId: BSONValue?) {
        self.matchedCount = matchedCount
        self.modifiedCount = modifiedCount
        self.upsertedId = upsertedId
    }
}

extension UpdateResult {
    var toSyncUpdateResult: SyncUpdateResult {
        return SyncUpdateResult(matchedCount: self.matchedCount,
                                modifiedCount: self.modifiedCount,
                                upsertedId: self.upsertedId?.value)
    }
}
