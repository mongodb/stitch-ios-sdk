import Foundation
import MongoSwift

// Options to use when executing a `findOneAndUpdate`, `findOneAndReplace`,
// or `findOneAndDelete` command on a `RemoteMongoCollection`.
public struct RemoteFindOneAndModifyOptions {
    // MARK: Initializer

    // Convenience initializer allowing any/all parameters to be optional
    public init(
        projection: Document? = nil,
        sort: Document? = nil,
        upsert: Bool? = nil,
        returnNewDocument: Bool? = nil) {
        self.projection = projection
        self.sort = sort
        self.upsert = upsert
        self.returnNewDocument = returnNewDocument
    }

    // MARK: Properties

    // Limits the fields to return for all matching documents.
    public let projection: Document?

    // The order in which to return matching documents.
    public let sort: Document?

    // Whether or not to perform an upsert, default is false
    // (only available for findOneAndReplace and findOneAndUpdate)
    public let upsert: Bool?

    // If this is true then the new document is returned,
    // Otherwise the old document is returned (default)
    // (only available for findOneAndReplace and findOneAndUpdate)
    public let returnNewDocument: Bool?
}
