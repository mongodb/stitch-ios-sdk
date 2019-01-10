import MongoSwift

/// The result of a `delete` command on a `RemoteMongoCollection`.
public struct RemoteDeleteResult: Decodable {
    /// The number of documents that were deleted.
    public let deletedCount: Int

    internal init(deletedCount: Int) {
        self.deletedCount = deletedCount
    }
}

public struct SyncDeleteResult {
    /// The number of documents that were deleted.
    public let deletedCount: Int

    internal init(deletedCount: Int) {
        self.deletedCount = deletedCount
    }
}

extension DeleteResult {
    var toSyncDeleteResult: SyncDeleteResult {
        return SyncDeleteResult(deletedCount: self.deletedCount)
    }
}
