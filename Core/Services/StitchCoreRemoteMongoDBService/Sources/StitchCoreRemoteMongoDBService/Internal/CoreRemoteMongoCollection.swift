import Foundation
import MongoSwift
import StitchCoreSDK

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
    
    private lazy var baseOperationArgs: Document = [
        "database": self.databaseName,
        "collection": self.name
    ]
    
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
    
    private enum RemoteFindOptionsKeys: String {
        case limit, projection = "project", sort
    }
    
    /**
     * Finds the documents in this collection which match the provided filter.
     *
     * - parameters:
     *   - filter: A `Document` that should match the query.
     *   - options: Optional `RemoteFindOptions` to use when executing the command.
     *
     * - important: Invoking this method by itself does not perform any network requests. You must call one of the
     *              methods on the resulting `CoreRemoteMongoReadOperation` instance to trigger the operation against
     *              the database.
     *
     * - returns: A `CoreRemoteMongoReadOperation` that allows retrieval of the resulting documents.
     */
    public func find(_ filter: Document = [:],
                     options: RemoteFindOptions? = nil) -> CoreRemoteMongoReadOperation<CollectionType> {
        var args = baseOperationArgs
        
        args["query"] = filter
        
        if let options = options {
            if let limit = options.limit {
                args[RemoteFindOptionsKeys.limit.rawValue] = limit
            }
            if let projection = options.projection {
                args[RemoteFindOptionsKeys.projection.rawValue] = projection
            }
            if let sort = options.sort {
                args[RemoteFindOptionsKeys.sort.rawValue] = sort
            }
        }
        
        return CoreRemoteMongoReadOperation<CollectionType>.init(command: "find", args: args, service: self.service)
    }
    
    /**
     * Runs an aggregation framework pipeline against this collection.
     *
     * - Parameters:
     *   - pipeline: An `[Document]` containing the pipeline of aggregation operations to perform.
     *
     * - important: Invoking this method by itself does not perform any network requests. You must call one of the
     *              methods on the resulting `CoreRemoteMongoReadOperation` instance to trigger the operation against the
     *              database.
     *
     * - returns: A `CoreRemoteMongoReadOperation` that allows retrieval of the resulting documents.
     */
    public func aggregate(_ pipeline: [Document]) -> CoreRemoteMongoReadOperation<CollectionType> {
        var args = baseOperationArgs
        
        args["pipeline"] = pipeline
        
        return CoreRemoteMongoReadOperation<CollectionType>.init(command: "aggregate", args: args, service: self.service)
    }
    
    private enum RemoteCountOptionsKeys: String {
        case limit
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
            args[RemoteCountOptionsKeys.limit.rawValue] = limit
        }
        
        return try service.callFunction(
            withName: "count",
            withArgs: [args],
            withRequestTimeout: nil
        )
    }
    
    /// Returns a version of the provided document with an ObjectId
    private func generateObjectIdIfMissing(_ document: Document) -> Document {
        if document["_id"] == nil {
            var newDoc = document
            newDoc["_id"] = ObjectId()
            return newDoc
        }
        return document
    }
    
    /**
     * Encodes the provided value to BSON and inserts it. If the value is missing an identifier, one will be
     * generated for it.
     *
     * - Parameters:
     *   - value: A `CollectionType` value to encode and insert.
     *
     * - Returns: The result of attempting to perform the insert.
     */
    public func insertOne(_ value: CollectionType) throws -> RemoteInsertOneResult {
        var args = baseOperationArgs
        
        args["document"] = generateObjectIdIfMissing(try BsonEncoder().encode(value))
        
        return try service.callFunction(
            withName: "insertOne",
            withArgs: [args],
            withRequestTimeout: nil
        )
    }
    
    /**
     * Encodes the provided values to BSON and inserts them. If any values are missing identifiers,
     * they will be generated.
     *
     * - Parameters:
     *   - documents: The `CollectionType` values to insert.
     *
     * - Returns: The result of attempting to perform the insert.
     */
    public func insertMany(_ documents: [CollectionType]) throws -> RemoteInsertManyResult {
        var args = baseOperationArgs
        
        let encoder = BsonEncoder()
        args["documents"] = try documents.map { generateObjectIdIfMissing(try encoder.encode($0)) }
        
        return try service.callFunction(
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
        
        return try service.callFunction(
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
    
    private enum RemoteUpdateOptionsKeys: String {
        case upsert
    }
    
    private func executeUpdate(filter: Document,
                               update: Document,
                               options: RemoteUpdateOptions?,
                               multi: Bool) throws -> RemoteUpdateResult {
        var args = baseOperationArgs
        
        args["query"] = filter
        args["update"] = update
        
        if let options = options, let upsert = options.upsert {
            args[RemoteUpdateOptionsKeys.upsert.rawValue] = upsert
        }
        
        return try service.callFunction(
            withName: multi ? "updateMany" : "updateOne",
            withArgs: [args],
            withRequestTimeout: nil
        )
    }
}
