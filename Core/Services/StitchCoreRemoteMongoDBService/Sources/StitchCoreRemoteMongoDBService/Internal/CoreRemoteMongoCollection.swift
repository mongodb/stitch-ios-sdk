// swiftlint:disable file_length
// swiftlint:disable type_body_length

import Foundation
import MongoSwift
import StitchCoreSDK

public class CoreRemoteMongoCollection<T: Codable>: Closable {
    /**
     * A `Codable` type associated with this `MongoCollection` instance.
     * This allows `CollectionType` values to be directly inserted into and
     * retrieved from the collection, by encoding/decoding them using the
     * `BSONEncoder` and `BSONDecoder`.
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
    private let dataSynchronizer: DataSynchronizer
    private var streams: [WeakReference<RawSSEStream>] = []
    private let client: CoreRemoteMongoClient
    private lazy var strongSelf = AnyClosable(self)

    public let sync: CoreSync<T>

    internal init(withName name: String,
                  withDatabaseName dbName: String,
                  withService service: CoreStitchServiceClient,
                  withClient client: CoreRemoteMongoClient) {
        self.name = name
        self.databaseName = dbName
        self.service = service
        self.client = client
        self.dataSynchronizer = client.dataSynchronizer
        self.sync = CoreSync.init(namespace: MongoNamespace.init(databaseName: databaseName,
                                                                 collectionName: name),
                                  dataSynchronizer: dataSynchronizer)
        self.client.register(closable: strongSelf)
    }

    /**
     * Creates a collection using the same datatabase name and collection name, but with a new `Codable` type with
     * which to encode and decode documents retrieved from and inserted into the collection.
     */
    public func withCollectionType<U: Codable>(_ type: U.Type) -> CoreRemoteMongoCollection<U> {
        return CoreRemoteMongoCollection<U>.init(
            withName: self.name,
            withDatabaseName: self.databaseName,
            withService: self.service,
            withClient: self.client
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
     * Returns one document from a collection or view which matches the
     * provided filter. If multiple documents satisfy the query, this method
     * returns the first document according to the query's sort order or natural
     * order.
     *
     * - parameters:
     *   - filter: A `Document` that should match the query.
     *   - options: Optional `RemoteFindOptions` to use when executing the command.
     *
     * - returns: The resulting `Document` or nil if no such document exists
     */
    public func findOne(_ filter: Document = [:], options: RemoteFindOptions? = nil) throws -> T? {
        var args = baseOperationArgs

        args["query"] = filter
        if let options = options {
            if let projection = options.projection {
                args[RemoteFindOptionsKeys.projection.rawValue] = projection
            }
            if let sort = options.sort {
                args[RemoteFindOptionsKeys.sort.rawValue] = sort
            }
        }

        return try self.service.callFunctionOptionalResult(withName: "findOne",
                                                           withArgs: [args],
                                                           withRequestTimeout: nil)
    }

    /**
     * Runs an aggregation framework pipeline against this collection.
     *
     * - Parameters:
     *   - pipeline: An `[Document]` containing the pipeline of aggregation operations to perform.
     *
     * - important: Invoking this method by itself does not perform any network requests. You must call one of the
     *              methods on the resulting `CoreRemoteMongoReadOperation` instance to trigger the operation against
     *              the database.
     *
     * - returns: A `CoreRemoteMongoReadOperation` that allows retrieval of the resulting documents.
     */
    public func aggregate(_ pipeline: [Document]) -> CoreRemoteMongoReadOperation<CollectionType> {
        var args = baseOperationArgs

        args["pipeline"] = pipeline

        return CoreRemoteMongoReadOperation<CollectionType>.init(
            command: "aggregate", args: args, service: self.service
        )
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

        args["document"] = generateObjectIdIfMissing(try BSONEncoder().encode(value))

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

        let encoder = BSONEncoder()
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

    private enum RemoteFindOneAndModifyOptionsKeys: String {
        case sort, projection, upsert, returnNewDocument
    }

    /**
     * Updates a single document in a collection based on a query filter and
     * returns the document in either its pre-update or post-update form. Unlike
     * `updateOne`, this action allows you to atomically find, update, and
     * return a document with the same command. This avoids the risk of other
     * update operations changing the document between separate find and update
     * operations.
     *
     * - parameters:
     *   - filter: A `Document` that should match the query.
     *   - update: A `Document` describing the update.
     *   - options: Optional `RemoteFindOneAndModifyOptions` to use when executing the command.
     *
     * - returns: The resulting `Document` or nil if no such document exists
     */
    public func findOneAndUpdate(filter: Document,
                                 update: Document,
                                 options: RemoteFindOneAndModifyOptions? = nil) throws -> T? {
        return try executeFindOneAndModify(funcName: "findOneAndUpdate",
                                           filter: filter,
                                           update: update,
                                           options: options)
    }

    /**
     * Overwrites a single document in a collection based on a query filter and
     * returns the document in either its pre-replacement or post-replacement
     * form. Unlike `updateOne`, this action allows you to atomically find,
     * replace, and return a document with the same command. This avoids the
     * risk of other update operations changing the document between separate
     * find and update operations.
     *
     * - parameters:
     *   - filter: A `Document` that should match the query.
     *   - replacement: A `Document` describing the update.
     *   - options: Optional `RemoteFindOneAndModifyOptions` to use when executing the command.
     *
     * - returns: The resulting `Document` or nil if no such document exists
     */
    public func findOneAndReplace(filter: Document,
                                  replacement: Document,
                                  options: RemoteFindOneAndModifyOptions? = nil) throws -> T? {
        return try executeFindOneAndModify(funcName: "findOneAndReplace",
                                          filter: filter,
                                          update: replacement,
                                          options: options)
    }

    /**
     * Removes a single document from a collection based on a query filter and
     * returns a document with the same form as the document immediately before
     * it was deleted. Unlike `deleteOne`, this action allows you to atomically
     * find and delete a document with the same command. This avoids the risk of
     * other update operations changing the document between separate find and
     * delete operations.
     *
     * - parameters:
     *   - filter: A `Document` that should match the query.
     *   - options: Optional `RemoteFindOneAndModifyOptions` to use when executing the command.
     *
     * - returns: The resulting `Document` or nil if no such document exists
     */
    public func findOneAndDelete(filter: Document,
                                 options: RemoteFindOneAndModifyOptions? = nil) throws -> T? {
        var args = baseOperationArgs

        args["filter"] = filter
        if let options = options {
            if let projection = options.projection {
                args[RemoteFindOneAndModifyOptionsKeys.projection.rawValue] = projection
            }
            if let sort = options.sort {
                args[RemoteFindOneAndModifyOptionsKeys.sort.rawValue] = sort
            }
        }

        return try self.service.callFunctionOptionalResult(withName: "findOneAndDelete",
                                                           withArgs: [args],
                                                           withRequestTimeout: nil)
    }

    /**
     * Opens a MongoDB change stream against the collection to watch for changes. The resulting stream will be notified
     * of all events on this collection that the active user is authorized to see based on the configured MongoDB
     * rules.
     *
     * - Parameters:
     *   - delegate: The delegate that will react to events and errors from the resulting change stream.
     *
     * - Returns: A reference to the change stream opened by this method.
     */
    public func watch(delegate: SSEStreamDelegate) throws -> RawSSEStream {
        var args = baseOperationArgs

        args["useCompactEvents"] = false

        let stream = try service.streamFunction(withName: "watch", withArgs: [args], delegate: delegate)
        self.streams.append(WeakReference(stream))
        return stream
    }

    /**
     * Opens a MongoDB change stream against the collection to watch for changes. The provided BSON document will be
     * used as a match expression filter on the change events coming from the stream.
     *
     * See https://docs.mongodb.com/manual/reference/operator/aggregation/match/ for documentation around how to define
     * a match filter.
     *
     * Defining the match expression to filter ChangeEvents is similar to defining the match expression for triggers:
     * https://docs.mongodb.com/stitch/triggers/database-triggers/
     *
     * - Parameters:
     *   - matchFilter: The $match filter to apply to incoming change events
     *   - delegate: The delegate that will react to events and errors from the resulting change stream.
     *
     * - Returns: A reference to the change stream opened by this method.
     */
    public func watch(matchFilter: Document, delegate: SSEStreamDelegate) throws -> RawSSEStream {
        var args = baseOperationArgs

        args["filter"] = matchFilter
        args["useCompactEvents"] = false

        let stream = try service.streamFunction(withName: "watch", withArgs: [args], delegate: delegate)
        self.streams.append(WeakReference(stream))
        return stream
    }

    /**
     * Opens a MongoDB change stream against the collection to watch for changes
     * made to specific documents. The documents to watch must be explicitly
     * specified by their _id.
     *
     * - Parameters:
     *   - ids: The list of _ids in the collection to watch.
     *   - delegate: The delegate that will react to events and errors from the resulting change stream.
     *
     * - Returns: A reference to the change stream opened by this method.
     */
    public func watch(
        ids: [BSONValue],
        delegate: SSEStreamDelegate,
        useCompactEvents: Bool
    ) throws -> RawSSEStream {
        var args = baseOperationArgs

        args["ids"] = ids
        args["useCompactEvents"] = useCompactEvents

        let stream = try service.streamFunction(withName: "watch", withArgs: [args], delegate: delegate)
        self.streams.append(WeakReference(stream))
        return stream
    }

    private enum RemoteUpdateOptionsKeys: String {
        case upsert
    }

    private func executeFindOneAndModify(funcName: String,
                                         filter: Document,
                                         update: Document,
                                         options: RemoteFindOneAndModifyOptions?) throws -> T? {
        var args = baseOperationArgs

        args["filter"] = filter
        args["update"] = update
        if let options = options {
            if let projection = options.projection {
                args[RemoteFindOneAndModifyOptionsKeys.projection.rawValue] = projection
            }
            if let sort = options.sort {
                args[RemoteFindOneAndModifyOptionsKeys.sort.rawValue] = sort
            }
            if options.upsert ?? false {
                args[RemoteFindOneAndModifyOptionsKeys.upsert.rawValue] = true
            }
            if options.returnNewDocument ?? false {
                args[RemoteFindOneAndModifyOptionsKeys.returnNewDocument.rawValue] = true
            }
        }

        return try self.service.callFunctionOptionalResult(withName: funcName,
                                                           withArgs: [args],
                                                           withRequestTimeout: nil)
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

    func close() {
        self.streams.forEach { streamRef in
            guard let stream = streamRef.reference else {
                return
            }

            stream.close()
        }
        self.streams.removeAll()
    }
}
