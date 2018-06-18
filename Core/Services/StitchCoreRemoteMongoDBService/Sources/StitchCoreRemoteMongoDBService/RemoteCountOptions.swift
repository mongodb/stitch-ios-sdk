import Foundation

/// Options to use when executing a `count` command on a `RemoteMongoCollection`.
public struct RemoteCountOptions {
    // MARK: Initializer
    
    /// Convenience initializer allowing any/all parameters to be optional
    public init(limit: Int64? = nil) {
        self.limit = limit
    }
    
    // MARK: Properties
    
    /// The maximum number of documents to count.
    public let limit: Int64?
}
