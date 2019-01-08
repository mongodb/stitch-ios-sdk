import MongoSwift

/// Options to use when executing an `updateOne` or `updateMany` command on a `RemoteMongoCollection`.
public struct RemoteUpdateOptions {
    // MARK: Initializer

    /// Convenience initializer allowing any/all parameters to be optional.
    public init(upsert: Bool? = nil) {
        self.upsert = upsert
    }

    // MARK: Properties

    /// When true, creates a new document if no document matches the query.
    public let upsert: Bool?
}

public struct SyncUpdateOptions {
    // MARK: Initializer

    /// Convenience initializer allowing any/all parameters to be optional.
    public init(upsert: Bool? = nil) {
        self.upsert = upsert
    }

    // MARK: Properties

    /// When true, creates a new document if no document matches the query.
    public let upsert: Bool?

    var toUpdateOptions: UpdateOptions {
        return UpdateOptions(upsert: self.upsert)
    }
}

extension UpdateOptions {
    var toSyncUpdateOptions: SyncUpdateOptions {
        return SyncUpdateOptions(upsert: self.upsert)
    }
}
