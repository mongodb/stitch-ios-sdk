import Foundation
import MongoSwift
import StitchCore
import StitchCoreRemoteMongoDBService

/**
 * A class representing a MongoDB collection accesible via the Stitch MongoDB service. Operations against the Stitch
 * server are performed asynchronously.
 */
public class RemoteMongoCollection<T: Codable> {
    private let dispatcher: OperationDispatcher
    private let proxy: CoreRemoteMongoCollection<T>
    
    internal init(withCollection collection: CoreRemoteMongoCollection<T>,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = collection
        self.dispatcher = dispatcher
    }
    
    // MARK: Properties
    
    /**
     * The name of this collection.
     */
    public var name: String {
        return proxy.name
    }
    
    /**
     * The name of the database containing this collection.
     */
    public var databaseName: String {
        return proxy.databaseName
    }
    
    // MARK: Custom Document Types
    
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
     * Creates a collection using the same datatabase name and collection name, but with a new `Codable` type with
     * which to encode and decode documents retrieved from and inserted into the collection.
     */
    public func withCollectionType<U: Codable>(_ type: U.Type) -> RemoteMongoCollection<U> {
        return RemoteMongoCollection<U>.init(
            withCollection: proxy.withCollectionType(type),
            withDispatcher: dispatcher
        )
    }
    
    // MARK: CRUD Operations
    
    /**
     * Finds the documents in this collection which match the provided filter.
     *
     * - parameters:
     *   - filter: A `Document` that should match the query.
     *   - options: Optional `RemoteFindOptions` to use when executing the command.
     *
     * - important: Invoking this method by itself does not perform any network requests. You must call one of the
     *              methods on the resulting `RemoteMongoReadOperation` instance to trigger the operation against the
     *              database.
     *
     * - returns: A `RemoteMongoReadOperation` that allows retrieval of the resulting documents.
     */
    public func find(_ filter: Document = [:],
                     options: RemoteFindOptions? = nil) -> RemoteMongoReadOperation<CollectionType> {
        return RemoteMongoReadOperation<CollectionType>.init(
            withOperations: proxy.find(filter, options: options), withDispatcher: dispatcher
        )
    }
    
    /**
     * Runs an aggregation framework pipeline against this collection.
     *
     * - Parameters:
     *   - pipeline: An `[Document]` containing the pipeline of aggregation operations to perform.
     *
     *   - important: Invoking this method by itself does not perform any network requests. You must call one of the
     *                methods on the resulting `RemoteMongoReadOperation` instance to trigger the operation against
     *                the database.
     *
     * - returns: A `RemoteMongoReadOperation` that allows retrieval of the resulting documents.
     */
    public func aggregate(_ pipeline: [Document]) -> RemoteMongoReadOperation<CollectionType> {
        return RemoteMongoReadOperation<CollectionType>.init(
            withOperations: proxy.aggregate(pipeline), withDispatcher: dispatcher
        )
    }
    
    /**
     * Counts the number of documents in this collection matching the provided filter.
     *
     * - parameters:
     *   - filter: a `Document`, the filter that documents must match in order to be counted.
     *   - options: Optional `RemoteCountOptions` to use when executing the command.
     *   - completionHandler: The completion handler to call when the count is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the count of the documents that matched the filter.
     */
    public func count(_ filter: Document = [:],
                      options: RemoteCountOptions? = nil,
                      _ completionHandler: @escaping (StitchResult<Int>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.count(filter, options: options)
        }
    }
    
    /**
     * Encodes the provided value to BSON and inserts it. If the value is missing an identifier, one will be
     * generated for it.
     *
     * - parameters:
     *   - value: A `CollectionType` value to encode and insert.
     *   - completionHandler: The completion handler to call when the insert is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the result of attempting to perform the insert, as
     *                        a `RemoteInsertOneResult`.
     *
     * - important: If the insert failed due to a request timeout, it does not necessarily indicate that the insert
     *              failed on the database. Application code should handle timeout errors with the assumption that the
     *              document may or may not have been inserted.
     */
    public func insertOne(_ value: CollectionType,
                          _ completionHandler: @escaping (StitchResult<RemoteInsertOneResult>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.insertOne(value)
        }
    }
    
    /**
     * Encodes the provided values to BSON and inserts them. If any values are missing identifiers,
     * they will be generated.
     *
     * - parameters:
     *   - documents: The `CollectionType` values to insert.
     *   - completionHandler: The completion handler to call when the insert is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`.
     *   - result: The result of attempting to perform the insert, or `nil` if the insert failed. If the operation is
     *                        successful, the result will contain the result of attempting to perform the insert, as
     *                        a `RemoteInsertManyResult`.
     *
     * - important: If the insert failed due to a request timeout, it does not necessarily indicate that the insert
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              documents may or may not have been inserted.
     */
    public func insertMany(_ documents: [CollectionType],
                           _ completionHandler: @escaping (StitchResult<RemoteInsertManyResult>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.insertMany(documents)
        }
    }
    
    /**
     * Deletes a single matching document from the collection.
     *
     * - parameters:
     *   - filter: A `Document` representing the match criteria.
     *   - completionHandler: The completion handler to call when the delete is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the result of performing the deletion, as
     *                        a `RemoteDeleteResult`.
     *
     * - important: If the delete failed due to a request timeout, it does not necessarily indicate that the delete
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              a document may or may not have been deleted.
     */
    public func deleteOne(_ filter: Document,
                          _ completionHandler: @escaping (StitchResult<RemoteDeleteResult>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.deleteOne(filter)
        }
    }
    
    /**
     * Deletes multiple documents from the collection.
     *
     * - parameters:
     *   - filter: A `Document` representing the match criteria.
     *   - completionHandler: The completion handler to call when the delete is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the result of performing the deletion, as
     *                        a `RemoteDeleteResult`.
     *
     * - important: If the delete failed due to a request timeout, it does not necessarily indicate that the delete
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              documents may or may not have been deleted.
     */
    public func deleteMany(_ filter: Document,
                           _ completionHandler: @escaping (StitchResult<RemoteDeleteResult>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.deleteMany(filter)
        }
    }
    
    /**
     * Updates a single document matching the provided filter in this collection.
     *
     * - parameters:
     *   - filter: A `Document` representing the match criteria.
     *   - update: A `Document` representing the update to be applied to a matching document.
     *   - options: Optional `RemoteUpdateOptions` to use when executing the command.
     *   - completionHandler: The completion handler to call when the update is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the result of attempting to update a document, as
     *                        a `RemoteUpdateResult`.
     *
     * - important: If the update failed due to a request timeout, it does not necessarily indicate that the update
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              a document may or may not have been updated.
     */
    public func updateOne(filter: Document,
                          update: Document,
                          options: RemoteUpdateOptions? = nil,
                          _ completionHandler: @escaping (StitchResult<RemoteUpdateResult>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.updateOne(filter: filter, update: update, options: options)
        }
    }
    
    /**
     * Updates mutiple documents matching the provided filter in this collection.
     *
     * - parameters:
     *   - filter: A `Document` representing the match criteria.
     *   - update: A `Document` representing the update to be applied to a matching document.
     *   - options: Optional `RemoteUpdateOptions` to use when executing the command.
     *   - completionHandler: The completion handler to call when the update is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the result of attempting to update multiple
     *                        documents, as a `RemoteUpdateResult`.
     *
     * - important: If the update failed due to a request timeout, it does not necessarily indicate that the update
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              documents may or may not have been updated.
     */
    public func updateMany(filter: Document,
                           update: Document,
                           options: RemoteUpdateOptions? = nil,
                           _ completionHandler: @escaping (StitchResult<RemoteUpdateResult>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.updateMany(filter: filter, update: update, options: options)
        }
    }
}
