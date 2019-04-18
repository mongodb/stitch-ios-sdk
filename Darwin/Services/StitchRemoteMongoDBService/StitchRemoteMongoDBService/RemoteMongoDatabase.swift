import Foundation
import MongoSwift
import StitchCore
import StitchCoreRemoteMongoDBService

/**
 * The `RemoteMongoDatabase` represents a MongoDB database, which holds a group
 * of collections that contain your data.
 *
 * It can be retrieved from the `RemoteMongoClient`.
 *
 * Use it to get `RemoteMongoCollection`s for reading and writing data.
 * 
 * - Note:
 * Before you can read or write data, a user must log in. See `StitchAuth`.
 * 
 * - SeeAlso:
 * `RemoteMongoClient`, `RemoteMongoCollection`
 */
public class RemoteMongoDatabase {
    private let dispatcher: OperationDispatcher
    private let proxy: CoreRemoteMongoDatabase

    internal init(withDatabase database: CoreRemoteMongoDatabase,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = database
        self.dispatcher = dispatcher
    }

    /**
     * The name of this database.
     */
    public var name: String {
        return proxy.name
    }

    /**
     * Gets a `RemoteMongoCollection`.
     *
     * - parameter name: the name of the collection to return
     * - returns: the collection
     */
    public func collection(_ collectionName: String) -> RemoteMongoCollection<Document> {
        return RemoteMongoCollection.init(
            withCollection: proxy.collection(collectionName),
            withDispatcher: self.dispatcher
        )
    }

    /**
     * Gets a `RemoteMongoCollection` with a specific default document type.
     *
     * - parameter name: the name of the collection to return
     * - parameter withCollectionType: the default class to cast any documents returned from the database into.
     * - returns: the collection
     */
    public func collection<T: Codable>(
        _ collectionName: String,
        withCollectionType type: T.Type
    ) -> RemoteMongoCollection<T> {
        return RemoteMongoCollection<T>.init(
            withCollection: self.proxy.collection(collectionName, withCollectionType: type),
            withDispatcher: self.dispatcher
        )
    }
}
