import Foundation
import MongoSwift

/// Options to use when executing a `find` command on a `RemoteMongoCollection`.
public struct RemoteFindOptions {
    // MARK: Initializer
    
    /// Convenience initializer allowing any/all parameters to be optional
    public init(limit: Int64? = nil, projection: Document? = nil, sort: Document? = nil) {
        self.limit = limit
        self.projection = projection
        self.sort = sort
    }
    
    // MARK: Properties
    
    /// The maximum number of documents to return.
    public let limit: Int64?
    
    /// Limits the fields to return for all matching documents.
    public let projection: Document?
    
    /// The order in which to return matching documents.
    public let sort: Document?
}
