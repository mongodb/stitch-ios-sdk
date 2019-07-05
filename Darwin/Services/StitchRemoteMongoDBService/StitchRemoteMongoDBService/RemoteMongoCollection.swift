//swiftlint:disable file_length
import Foundation
import MongoSwift
import StitchCore
import StitchCoreRemoteMongoDBService

/**
 * The `RemoteMongoCollection` represents a MongoDB collection.
 *
 * You can get an instance from a `RemoteMongoDatabase`.
 *
 * Create, read, update, and delete methods are available.
 * 
 * Operations against the Stitch server are performed asynchronously.
 *
 * - Note:
 * Before you can read or write data, a user must log in. See `StitchAuth`.
 * 
 * - SeeAlso:
 * `RemoteMongoClient`, `RemoteMongoDatabase`
 */
public class RemoteMongoCollection<T: Codable> {
    private let dispatcher: OperationDispatcher
    private let proxy: CoreRemoteMongoCollection<T>
    public let sync: Sync<T>

    internal init(withCollection collection: CoreRemoteMongoCollection<T>,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = collection
        self.dispatcher = dispatcher
        self.sync = Sync.init(proxy: self.proxy.sync)
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
     * `BSONEncoder` and `BSONDecoder`.
     * 
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
     * Finds the documents in this collection that match the provided filter.
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
     * You can use any
     * [aggregation stage](https://docs.mongodb.com/manual/reference/operator/aggregation-pipeline/index.html)
     * except for the following:      
     *   - $collStats
     *   - $currentOp
     *   - $lookup
     *   - $out
     *   - $indexStats
     *   - $facet
     *   - $graphLookup
     *   - $text
     *   - $geoNear
     *
     * - important: Invoking this method by itself does not perform any network requests. You must call one of the
     *     methods on the resulting `RemoteMongoReadOperation` instance to trigger the operation against
     *     the database.
     *
     * - Parameters:
     *   - pipeline: An array of `Document`s containing the pipeline of aggregation operations to perform.
     *
     * - returns: A `RemoteMongoReadOperation` that allows retrieval of the resulting documents.
     */
    public func aggregate(_ pipeline: [Document]) -> RemoteMongoReadOperation<CollectionType> {
        return RemoteMongoReadOperation<CollectionType>.init(
            withOperations: proxy.aggregate(pipeline), withDispatcher: dispatcher
        )
    }

    /**
     * Finds a document in this collection that matches the provided filter.
     *
     * - parameters:
     *   - filter: A `Document` that should match the query.
     *   - options: Optional `RemoteFindOptions` to use when executing the command.

     * - returns: A the resulting `Document` or nil if no such document exists
     */
    public func findOne(_ filter: Document = [:],
                        options: RemoteFindOptions? = nil,
                        _ completionHandler: @escaping (StitchResult<CollectionType?>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.findOne(filter, options: options)
        }
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
     * Encodes the provided value as BSON and inserts it. If the value is missing an identifier, one will be
     * generated for it.
     *
     * - important: If the insert failed due to a request timeout, it does not necessarily indicate that the insert
     *              failed on the database. Application code should handle timeout errors with the assumption that the
     *              document may or may not have been inserted.
     *
     * - parameters:
     *   - value: A `CollectionType` value to encode and insert.
     *   - completionHandler: The completion handler to call when the insert is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the result of attempting to perform the insert, as
     *                        a `RemoteInsertOneResult`.
     *
     */
    public func insertOne(_ value: CollectionType,
                          _ completionHandler: @escaping (StitchResult<RemoteInsertOneResult>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.insertOne(value)
        }
    }

    /**
     * Encodes the provided values as BSON and inserts them. If any values are missing identifiers,
     * they will be generated.
     *
     * - important: If the insert failed due to a request timeout, it does not necessarily indicate that the insert
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              documents may or may not have been inserted.
     *
     * - parameters:
     *   - documents: The `CollectionType` values to insert.
     *   - completionHandler: The completion handler to call when the insert is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`.
     *   - result: The result of attempting to perform the insert, or `nil` if the insert failed. If the operation is
     *                        successful, the result will contain the result of attempting to perform the insert, as
     *                        a `RemoteInsertManyResult`.
     *
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
     * - important: If the delete failed due to a request timeout, it does not necessarily indicate that the delete
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              a document may or may not have been deleted.
     *
     * - parameters:
     *   - filter: A `Document` representing the match criteria.
     *   - completionHandler: The completion handler to call when the delete is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the result of performing the deletion, as
     *                        a `RemoteDeleteResult`.
     *
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
     * - important: If the delete failed due to a request timeout, it does not necessarily indicate that the delete
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              documents may or may not have been deleted.
     *
     * - parameters:
     *   - filter: A `Document` representing the match criteria.
     *   - completionHandler: The completion handler to call when the delete is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the result of performing the deletion, as
     *                        a `RemoteDeleteResult`.
     *
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
     * - important: If the update failed due to a request timeout, it does not necessarily indicate that the update
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              a document may or may not have been updated.
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
     * - important: If the update failed due to a request timeout, it does not necessarily indicate that the update
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              documents may or may not have been updated.
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
     */
    public func updateMany(filter: Document,
                           update: Document,
                           options: RemoteUpdateOptions? = nil,
                           _ completionHandler: @escaping (StitchResult<RemoteUpdateResult>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.updateMany(filter: filter, update: update, options: options)
        }
    }

    /**
     * Finds a document in this collection which matches the provided filter and
     * performs the given update on that document.
     *
     * - important: If the update failed due to a request timeout, it does not necessarily indicate that the update
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              documents may or may not have been updated.
     *
     * - parameters:
     *   - filter: A `Document` that should match the query.
     *   - update: A `Document` describing the update.
     *   - options: Optional `RemoteFindOneAndModifyOptions` to use when executing the command.
     *   - completionHandler: The completion handler to call when the update is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the resulting document or nil if the query
     *                        matched no documents.
     *
     */
    public func findOneAndUpdate(filter: Document,
                                 update: Document,
                                 options: RemoteFindOneAndModifyOptions? = nil,
                                 _ completionHandler: @escaping (StitchResult<CollectionType?>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.findOneAndUpdate(filter: filter, update: update, options: options)
        }
    }

    /**
     * Finds a document in this collection which matches the provided filter and
     * replaces that document with the given document.
     *
     * - important: If the update failed due to a request timeout, it does not necessarily indicate that the update
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              documents may or may not have been updated.
     *
     * - parameters:
     *   - filter: A `Document` that should match the query.
     *   - replacement: A `Document` to replace the matched document with.
     *   - options: Optional `RemoteFindOneAndModifyOptions` to use when executing the command.
     *   - completionHandler: The completion handler to call when the update is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the resulting document or nil if the query
     *                        matched no documents.
     *
     */
    public func findOneAndReplace(filter: Document,
                                  replacement: Document,
                                  options: RemoteFindOneAndModifyOptions? = nil,
                                  _ completionHandler: @escaping (StitchResult<CollectionType?>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.findOneAndReplace(filter: filter, replacement: replacement, options: options)
        }
    }

    /**
     * Finds a document in this collection which matches the provided filter and delete the document.
     *
     * - important: If the update failed due to a request timeout, it does not necessarily indicate that the update
     *              failed on the database. Application code should handle timeout errors with the assumption that
     *              documents may or may not have been updated.
     *
     * - parameters:
     *   - filter: A `Document` that should match the query.
     *   - options: Optional `RemoteFindOneAndModifyOptions` to use when executing the command.
     *                        Note: findOneAndDelete() only accepts the sort and projection options
     *   - completionHandler: The completion handler to call when the update is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the resulting document or nil if the query
     *                        matched no documents.
     *
     */
    public func findOneAndDelete(filter: Document,
                                 options: RemoteFindOneAndModifyOptions? = nil,
                                 _ completionHandler: @escaping (StitchResult<CollectionType?>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.findOneAndDelete(filter: filter, options: options)
        }
    }

    /**
     * Opens a MongoDB change stream against the collection to watch for changes. The resulting stream will be notified
     * of all events on this collection that the active user is authorized to see based on the configured MongoDB
     * rules.
     *
     * - This method has a generic type parameter of DelegateT, which is the type of the delegate that will react to
     *   events on the stream. This can be any type as long as it conforms to the `ChangeStreamDelegate` protocol, and
     *   the `DocumentT` type parameter on the delegate matches the `T` parameter of this collection.
     *
     * - When this method returns the `ChangeStreamSession`, the change stream may not yet be open. The stream is
     *   not open until the `didOpen` method is called on the provided delegate. This means that events that happen
     *   after this method returns will not necessarily be received by this stream until the `didOpen` method is
     *   called.
     *
     * - Parameters:
     *   - delegate: The delegate that will react to events and errors from the resulting change stream.
     *
     * - Returns: A reference to the change stream opened by this method.
     */
    public func watch<DelegateT: ChangeStreamDelegate>(
        delegate: DelegateT
    ) throws -> ChangeStreamSession<T> where DelegateT.DocumentT == T {
        let session = ChangeStreamSession.init(changeEventType: .fullDocument(withDelegate: delegate))

        let rawStream = try self.proxy.watch(delegate: session.internalDelegate)
        session.rawStream = rawStream

        return session
    }

    /**
     * Opens a MongoDB change stream against the collection to watch for changes. The provided BSON document will be
     * used as a match expression filter on the change events coming from the stream.
     *
     * - See https://docs.mongodb.com/manual/reference/operator/aggregation/match/ for documentation around how to
     *   define a match filter.
     *
     * - Defining the match expression to filter ChangeEvents is similar to defining the match expression for triggers:
     *   https://docs.mongodb.com/stitch/triggers/database-triggers/
     *
     * - This method has a generic type parameter of DelegateT, which is the type of the delegate that will react to
     *   events on the stream. This can be any type as long as it conforms to the `ChangeStreamDelegate` protocol, and
     *   the `DocumentT` type parameter on the delegate matches the `T` parameter of this collection.
     *
     * - When this method returns the `ChangeStreamSession`, the change stream may not yet be open. The stream is
     *   not open until the `didOpen` method is called on the provided delegate. This means that events that happen
     *   after this method returns will not necessarily be received by this stream until the `didOpen` method is
     *   called.
     *
     * - Parameters:
     *   - matchFilter: The $match filter to apply to incoming change events
     *   - delegate: The delegate that will react to events and errors from the resulting change stream.
     *
     * - Returns: A reference to the change stream opened by this method.
     */
    public func watch<DelegateT: ChangeStreamDelegate >(
        matchFilter: Document,
        delegate: DelegateT
    ) throws -> ChangeStreamSession<T> where DelegateT.DocumentT == T {
        let session = ChangeStreamSession.init(changeEventType: .fullDocument(withDelegate: delegate))

        let rawStream = try self.proxy.watch(matchFilter: matchFilter,
                                             delegate: session.internalDelegate)
        session.rawStream = rawStream

        return session
    }

    /**
     * Opens a MongoDB change stream against the collection to watch for changes
     * made to specific documents. The documents to watch must be explicitly
     * specified by their _id.
     *
     * - This method's forStreamType can be initialized with generic type parameters of FullDelegateT or
     *   CompactDelegateT, which are the type of the delegate that will react to events on the stream. These can be
     *   any type as long as they conform to either the `ChangeStreamDelegate` protocol or
     *   `CompactChangeStreamDelegate` protocol respectively, and the `DocumentT` type parameter on the delegate
     *   matches the `T` parameter of this collection.
     *
     * - When this method returns the `ChangeStreamSession`, the change stream may not yet be open. The stream is
     *   not open until the `didOpen` method is called on the provided delegate. This means that events that happen
     *   after this method returns will not necessarily be received by this stream until the `didOpen` method is
     *   called.
     *
     * - Parameters:
     *   - ids: The list of _ids in the collection to watch.
     *   - streamType: Whether to use a full or compact stream.
     *                 This contains the delegate that will react to events
     *                 and errors from the resulting change stream.
     *
     * - Returns: A reference to the change stream opened by this method.
     */
    public func watch (
        ids: [BSONValue],
        forStreamType streamType: ChangeStreamType<T>
    ) throws -> ChangeStreamSession<T> {
        let session = ChangeStreamSession.init(changeEventType: streamType)

        let rawStream = try self.proxy.watch(ids: ids,
                                             delegate: session.internalDelegate,
                                             useCompactEvents: streamType.useCompactEvents)
        session.rawStream = rawStream

        return session
    }
}
