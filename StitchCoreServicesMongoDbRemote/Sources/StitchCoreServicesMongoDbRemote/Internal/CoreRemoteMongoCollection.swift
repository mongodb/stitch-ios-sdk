import Foundation
import MongoSwift
import StitchCore

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
    
    /**
     * The name of the database containing this collection.
     */
    public let databaseName: String
    
    private var baseOperationArgs: Document {
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
    
    /**
     * Creates a collection using the same datatabase name and collection name, but with a new `Codable` type with
     * which to encode and decode documents retrieved from and inserted into the collection.
     */
    public func withCollectionType<U: Codable>(_ type: U.Type) -> CoreRemoteMongoCollection<U> {
        return CoreRemoteMongoCollection<U>.init(
            withName: self.name,
            withDatabaseName: self.databaseName,
            withService: self.service
        )
    }
    
    /**
     * Finds the documents in this collection which match the provided filter.
     *
     * - Parameters:
     *   - filter: A `Document` that should match the query.
     *   - options: Optional `RemoteFindOptions` to use when executing the command.
     *
     * - Returns: A `RemoteMongoCursor` over the resulting `Document`s
     */
    public func find(_ filter: Document = [:],
                     options: RemoteFindOptions? = nil) throws -> CoreRemoteMongoCursor<CollectionType> {
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
                withRequestTimeout: nil
        )
        
        return CoreRemoteMongoCursor<CollectionType>.init(documents: resultCollection.makeIterator())
    }
    
    /**
     * Runs an aggregation framework pipeline against this collection.
     *
     * - Parameters:
     *   - pipeline: An `[Document]` containing the pipeline of aggregation operations to perform.
     *
     * - Returns: A `RemoteMongoCursor` over the resulting `Document`s.
     */
    public func aggregate(_ pipeline: [Document]) throws -> CoreRemoteMongoCursor<CollectionType> {
        var args = baseOperationArgs
        
        args["pipeline"] = pipeline
        
        let resultCollection: [CollectionType] =
            try service.callFunctionInternal(
                withName: "aggregate",
                withArgs: [args],
                withRequestTimeout: nil
        )
        
        return CoreRemoteMongoCursor<CollectionType>.init(documents: resultCollection.makeIterator())
    }
    
    /**
     * Counts the number of documents in this collection matching the provided filter.
     *
     * - Parameters:
     *   - filter: a `Document`, the filter that documents must match in order to be counted.
     *   - options: Optional `RemoteCountOptions` to use when executing the command.
     *
     * - Returns: The count of the documents that matched the filter.
     */
    public func count(_ filter: Document = [:],
                      options: RemoteCountOptions? = nil) throws -> Int {
        var args = baseOperationArgs
        args["query"] = filter
        
        if let options = options, let limit = options.limit {
            args[RemoteCountOptions.CodingKeys.limit.rawValue] = limit
        }
        
        return try service.callFunctionInternal(
            withName: "count",
            withArgs: [args],
            withRequestTimeout: nil
        )
    }
    
    /**
     * Encodes the provided value to BSON and inserts it. If the value is missing an identifier, one will be
     * generated for it by the MongoDB Stitch server.
     *
     * - Parameters:
     *   - value: A `CollectionType` value to encode and insert.
     *
     * - Returns: The result of attempting to perform the insert.
     */
    public func insertOne(_ value: CollectionType,
                          timeout: TimeInterval? = nil) throws -> RemoteInsertOneResult {
        var args = baseOperationArgs
        
        args["document"] = try BsonEncoder().encode(value)
        
        return try service.callFunctionInternal(
            withName: "insertOne",
            withArgs: [args],
            withRequestTimeout: nil
        )
    }
    
    /**
     * Encodes the provided values to BSON and inserts them. If any values are missing identifiers,
     * the MongoDB Stitch server will generate them.
     *
     * - Parameters:
     *   - documents: The `CollectionType` values to insert.
     *
     * - Returns: The result of attempting to perform the insert.
     */
    public func insertMany(_ values: [CollectionType]) throws -> RemoteInsertManyResult {
        var args = baseOperationArgs
        
        let encoder = BsonEncoder()
        args["documents"] = try values.map { try encoder.encode($0) }
        
        return try service.callFunctionInternal(
            withName: "insertMany",
            withArgs: [args],
            withRequestTimeout: nil
        )
    }

    /**
     * Deletes a single matching document from the collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria.
     *
     * - Returns: The result of performing the deletion.
     */
    public func deleteOne(_ filter: Document) throws -> RemoteDeleteResult {
        return try executeDelete(filter, multi: false)
    }
    
    
    /**
     * Deletes multiple documents
     *
     * - Parameters:
     *   - filter: Document representing the match criteria
     *
     * - Returns: The result of performing the deletion.
     */
    public func deleteMany(_ filter: Document) throws -> RemoteDeleteResult {
        return try executeDelete(filter, multi: true)
    }
    
    private func executeDelete(_ filter: Document,
                              multi: Bool) throws -> RemoteDeleteResult {
        var args = baseOperationArgs
        args["query"] = filter
        
        return try service.callFunctionInternal(
            withName: multi ? "deleteMany" : "deleteOne",
            withArgs: [args],
            withRequestTimeout: nil
        )
    }
    
    /**
     * Updates a single document matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria.
     *   - update: A `Document` representing the update to be applied to a matching document.
     *   - options: Optional `RemoteUpdateOptions` to use when executing the command.
     *
     * - Returns: The result of attempting to update a document.
     */
    public func updateOne(filter: Document,
                          update: Document,
                          options: RemoteUpdateOptions? = nil) throws -> RemoteUpdateResult {
        return try executeUpdate(filter: filter,
                                 update: update,
                                 options: options,
                                 multi: false)
    }
    
    /**
     * Updates multiple documents matching the provided filter in this collection.
     *
     * - Parameters:
     *   - filter: A `Document` representing the match criteria.
     *   - update: A `Document` representing the update to be applied to matching documents.
     *   - options: Optional `RemoteUpdateOptions` to use when executing the command.
     *   - timeout: Optional `TimeInterval` to specify the number of seconds to wait for a response before failing
     *              with an error. A timeout does not necessarily indicate that the update failed. Application code
     *              should handle timeout errors with the assumption that documents may or may not have been
     *              updated.
     *
     * - Returns: The result of attempting to update multiple documents.
     */
    public func updateMany(filter: Document,
                          update: Document,
                          options: RemoteUpdateOptions? = nil) throws -> RemoteUpdateResult {
        return try executeUpdate(filter: filter,
                                 update: update,
                                 options: options,
                                 multi: true)
    }
    
    private func executeUpdate(filter: Document,
                               update: Document,
                               options: RemoteUpdateOptions?,
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
            withRequestTimeout: nil
        )
    }
}
