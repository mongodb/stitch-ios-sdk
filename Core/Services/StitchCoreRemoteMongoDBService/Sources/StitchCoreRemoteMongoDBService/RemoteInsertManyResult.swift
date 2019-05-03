import Foundation
import MongoSwift

/// The result of an `insertMany` command on a `RemoteMongoCollection`.
public struct RemoteInsertManyResult: Decodable {
    /// Map of the index of the inserted document to the id of the inserted document.
    public let insertedIds: [Int64: BSONValue]

    /// Given an ordered array of insertedIds, creates a corresponding `RemoteInsertManyResult`.
    internal init(fromArray arr: [BSONValue]) {
        var inserted = [Int64: BSONValue]()
        zip(arr.indices, arr).forEach { (index, value) in
            inserted[Int64(index)] = value
        }
        self.insertedIds = inserted
    }

    /// :nodoc:
    public init(from decoder: Decoder) throws {
        let doc = try decoder.singleValueContainer().decode(Document.self)
        guard let insertedIdsArray = doc[CodingKeys.insertedIds.rawValue] as? [BSONValue] else {
            throw RuntimeError.internalError(message: "error decoding insert many result")
        }

        self.init(fromArray: insertedIdsArray)
    }

    internal enum CodingKeys: String, CodingKey {
        case insertedIds
    }
}

public class SyncInsertManyResult {
    /// Map of the index of the inserted document to the id of the inserted document.
    public let insertedIds: [Int: BSONValue?]

    /// Given an ordered array of insertedIds, creates a corresponding `RemoteInsertManyResult`.
    internal init(insertedIds: [Int: BSONValue?]) {
        self.insertedIds = insertedIds
    }
}

extension InsertManyResult {
    var toSyncInsertManyResult: SyncInsertManyResult {
        return SyncInsertManyResult(insertedIds: self.insertedIds)
    }
}
