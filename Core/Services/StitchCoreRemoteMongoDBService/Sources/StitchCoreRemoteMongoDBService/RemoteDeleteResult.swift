import Foundation

/// The result of a `delete` command on a `RemoteMongoCollection`.
public struct RemoteDeleteResult: Decodable {
    /// The number of documents that were deleted.
    public let deletedCount: Int
}
