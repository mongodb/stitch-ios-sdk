import Foundation
import MongoSwift
import StitchCore

/// Options to use when executing a `find` command on a `RemoteMongoCollection`.
public struct RemoteFindOptions {
    /// The maximum number of documents to return.
    public let limit: Int64?
    
    /// Limits the fields to return for all matching documents.
    public let projection: Document?
    
    /// The order in which to return matching documents.
    public let sort: Document?
    
    /// Convenience initializer allowing any/all parameters to be optional
    public init(limit: Int64? = nil, projection: Document? = nil, sort: Document? = nil) {
        self.limit = limit
        self.projection = projection
        self.sort = sort
    }
    
    // Encode everything
    fileprivate enum CodingKeys: String, CodingKey {
        case limit, projection, sort
    }
}

/// Options to use when executing a `count` command on a `RemoteMongoCollection`.
public struct RemoteCountOptions {
    /// The maximum number of documents to count.
    public let limit: Int64?
    
    /// Convenience initializer allowing any/all parameters to be optional
    public init(limit: Int64? = nil) {
        self.limit = limit
    }
    
    // Encode everything
    fileprivate enum CodingKeys: String, CodingKey {
        case limit
    }
}

/// The result of an `insertOne` command on a `RemoteMongoCollection`.
public struct RemoteInsertOneResult: Decodable {
    /// The identifier that was inserted. If the document doesn't have an identifier, this value
    /// will be generated and added to the document before insertion.
    public let insertedId: BsonValue
    
    public enum CodingKeys: String, CodingKey {
        case insertedId
    }
    
    // Workaround until SWIFT-104 is merged, which will make BsonValue `Decodable`
    public init(from decoder: Decoder) throws {
        let doc = try decoder.singleValueContainer().decode(Document.self)
        guard let insertedId = doc[CodingKeys.insertedId.rawValue] else {
            throw MongoError.invalidResponse()
        }
        self.insertedId = insertedId
    }
}

/// The result of an `insertMany` command on a `RemoteMongoCollection`.
public struct RemoteInsertManyResult: Decodable {
    /// Map of the index of the inserted document to the id of the inserted document.
    public let insertedIds: [Int64: BsonValue]
    
    public enum CodingKeys: String, CodingKey {
        case insertedIds
    }
    
    /// Given an ordered array of insertedIds, creates a corresponding InsertManyResult.
    internal init(fromArray arr: [BsonValue]) {
        var inserted = [Int64: BsonValue]()
        for (i, id) in arr.enumerated() {
            let index = Int64(i)
            inserted[index] = id
        }
        self.insertedIds = inserted
    }
    
    public init(from decoder: Decoder) throws {
        let doc = try decoder.singleValueContainer().decode(Document.self)
        guard let insertedIdsArray = doc[CodingKeys.insertedIds.rawValue] as? [BsonValue] else {
            throw MongoError.invalidResponse()
        }
        
        self.init(fromArray: insertedIdsArray)
    }
}

/// Options to use when executing an `updateOne` or `updateMany` command on a `RemoteMongoCollection`.
public struct RemoteUpdateOptions {
    /// When true, creates a new document if no document matches the query.
    public let upsert: Bool?
    
    /// Convenience initializer allowing any/all parameters to be optional
    public init(upsert: Bool? = nil) {
        self.upsert = upsert
    }
    
    // Encode everything except readConcern
    fileprivate enum CodingKeys: String, CodingKey {
        case upsert
    }
}

/// The result of an `updateOne` or `updateMany` operation a `RemoteMongoCollection`.
public struct RemoteUpdateResult: Decodable {
    /// The number of documents that matched the filter.
    public let matchedCount: Int
    
    /// The identifier of the inserted document if an upsert took place.
    public let upsertedId: BsonValue?
    
    /// Given a server response to an update command, creates a corresponding
    /// `UpdateResult`. If the `from` Document does not have `matchedCount`
    /// the initialization will fail. The document may
    /// optionally have an `upsertedId` field.
    internal init(from document: Document) throws {
        guard let matched = document["matchedCount"] as? Int else {
            throw MongoError.invalidResponse()
        }
        self.matchedCount = matched
        self.upsertedId = document["upsertedId"]
    }
    
    public init(from decoder: Decoder) throws {
        let doc = try decoder.singleValueContainer().decode(Document.self)
        try self.init(from: doc)
    }
}

/// The result of a `delete` command on a `MongoCollection`.
public struct RemoteDeleteResult: Decodable {
    /// The number of documents that were deleted.
    public let deletedCount: Int
}

public class CoreRemoteMongoCollection<T: Codable> {
    
    /**
     * A `Codable` type associated with this `MongoCollection` instance.
     * This allows `CollectionType` values to be directly inserted into and
     * retrieved from the collection, by encoding/decoding them using the
     * `BsonEncoder` and `BsonDecoder`.
     * This type association only exists in the context of this particular
     * `MongoCollection` instance. It is the responsibility of the user to
     * ensure that any data already stored in the collection was encoded
     * from this same type.
     */
    public typealias CollectionType = T
    
    /**
     * The name of this collection.
     */
    public let name: String
    
    private let databaseName: String
    
    private var baseOperationArgs: Document {
//        let args: Document [
//            "database": self.databaseName,
//            "collection": self.name,
//            "query": filter
//        ]
//        return args
        return [
            "database": self.databaseName,
            "collection": self.name
        ]
    }
    
    private let service: CoreStitchServiceClient
    
    public init(withName name: String,
                withDatabaseName dbName: String,
                withService service: CoreStitchServiceClient) {
        self.name = name
        self.databaseName = dbName
        self.service = service
    }
    
    // count
    
    // find
    public func find(_ filter: Document = [:],
                     options: RemoteFindOptions? = nil,
                     timeout: TimeInterval? = nil) throws -> CoreRemoteMongoCursor<CollectionType> {
        var args = baseOperationArgs
        
        args["query"] = filter
        
        if let options = options {
            if let limit = options.limit {
                args[RemoteFindOptions.CodingKeys.limit.rawValue] = limit
            }
            if let projection = options.projection {
                args[RemoteFindOptions.CodingKeys.projection.rawValue] = projection
            }
            if let sort = options.sort {
                args[RemoteFindOptions.CodingKeys.sort.rawValue] = sort
            }
        }
        
        let resultCollection: [CollectionType] =
            try service.callFunctionInternal(
                withName: "find",
                withArgs: [args],
                withRequestTimeout: timeout
        )
        
        return CoreRemoteMongoCursor<CollectionType>.init(documents: resultCollection.makeIterator())
    }
    
    // aggregate
    public func aggregate(_ pipeline: [Document], timeout: TimeInterval?) throws -> CoreRemoteMongoCursor<CollectionType> {
        var args = baseOperationArgs
        
        args["pipeline"] = pipeline
        
        let resultCollection: [CollectionType] =
            try service.callFunctionInternal(
                withName: "aggregate",
                withArgs: [args],
                withRequestTimeout: timeout
        )
        
        return CoreRemoteMongoCursor<CollectionType>.init(documents: resultCollection.makeIterator())
    }
    
    // count
    public func count(_ filter: Document = [:],
                      options: RemoteCountOptions? = nil,
                      timeout: TimeInterval? = nil) throws -> Int {
        var args = baseOperationArgs
        args["query"] = filter
        
        if let options = options, let limit = options.limit {
            args[RemoteCountOptions.CodingKeys.limit.rawValue] = limit
        }
        
        return try service.callFunctionInternal(
            withName: "count",
            withArgs: [args],
            withRequestTimeout: timeout
        )
    }
    
    // insertOne
    public func insertOne(_ value: CollectionType,
                          timeout: TimeInterval? = nil) throws -> RemoteInsertOneResult {
        var args = baseOperationArgs
        
        args["document"] = try BsonEncoder().encode(value)
        
        return try service.callFunctionInternal(
            withName: "insertOne",
            withArgs: [args],
            withRequestTimeout: timeout
        )
    }
    
    // insertMany
    public func insertMany(_ values: [CollectionType],
                           timeout: TimeInterval? = nil) throws -> RemoteInsertOneResult {
        var args = baseOperationArgs
        
        let encoder = BsonEncoder()
        args["documents"] = try values.map { try encoder.encode($0) }
        
        return try service.callFunctionInternal(
            withName: "insertMany",
            withArgs: [args],
            withRequestTimeout: timeout
        )
    }

    // deleteOne
    public func deleteOne(_ filter: Document,
                          timeout: TimeInterval? = nil) throws -> RemoteDeleteResult {
        return try executeDelete(filter, timeout: timeout, multi: false)
    }
    
    
    // deleteMany
    public func deleteMany(_ filter: Document,
                          timeout: TimeInterval? = nil) throws -> RemoteDeleteResult {
        return try executeDelete(filter, timeout: timeout, multi: true)
    }
    
    private func executeDelete(_ filter: Document,
                              timeout: TimeInterval? = nil,
                              multi: Bool) throws -> RemoteDeleteResult {
        var args = baseOperationArgs
        args["query"] = filter
        
        return try service.callFunctionInternal(
            withName: multi ? "deleteMany" : "deleteOne",
            withArgs: [args],
            withRequestTimeout: timeout
        )
    }
    
    // updateOne
    public func updateOne(filter: Document,
                          update: Document,
                          options: RemoteUpdateOptions? = nil,
                          timeout: TimeInterval? = nil) throws -> RemoteUpdateResult {
        return try executeUpdate(filter: filter,
                                 update: update,
                                 options: options,
                                 timeout: timeout,
                                 multi: false)
    }
    
    // updateMany
    public func updateMany(filter: Document,
                          update: Document,
                          options: RemoteUpdateOptions? = nil,
                          timeout: TimeInterval? = nil) throws -> RemoteUpdateResult {
        return try executeUpdate(filter: filter,
                                 update: update,
                                 options: options,
                                 timeout: timeout,
                                 multi: true)
    }
    
    private func executeUpdate(filter: Document,
                               update: Document,
                               options: RemoteUpdateOptions?,
                               timeout: TimeInterval?,
                               multi: Bool) throws -> RemoteUpdateResult {
        var args = baseOperationArgs
        
        args["query"] = filter
        args["update"] = update
        
        if let options = options, let upsert = options.upsert {
            args["upsert"] = upsert
        }
        
        return try service.callFunctionInternal(
            withName: multi ? "updateMany" : "updateOne",
            withArgs: [args],
            withRequestTimeout: timeout
        )
    }
}
