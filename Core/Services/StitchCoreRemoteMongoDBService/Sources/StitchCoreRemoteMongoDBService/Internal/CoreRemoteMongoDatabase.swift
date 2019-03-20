import Foundation
import MongoSwift
import StitchCoreSDK

public class CoreRemoteMongoDatabase {
    /**
     * The name of this database.
     */
    public let name: String

    private let service: CoreStitchServiceClient
    private let client: CoreRemoteMongoClient

    public init(withName name: String,
                withService service: CoreStitchServiceClient,
                withClient client: CoreRemoteMongoClient) {
        self.name = name
        self.service = service
        self.client = client
    }

    /**
     * Gets a collection.
     *
     * - parameter name: the name of the collection to return
     * - returns: the collection
     */
    public func collection(_ collectionName: String) -> CoreRemoteMongoCollection<Document> {
        return self.collection(collectionName, withCollectionType: Document.self)
    }

    /**
     * Gets a collection with a specific default document type.
     *
     * - parameter name: the name of the collection to return
     * - parameter withCollectionType: the default class to cast any documents returned from the database into.
     * - returns: the collection
     */
    public func collection<T: Codable>(
        _ collectionName: String,
        withCollectionType type: T.Type
    ) -> CoreRemoteMongoCollection<T> {
        return CoreRemoteMongoCollection<T>.init(
            withName: collectionName,
            withDatabaseName: self.name,
            withService: self.service,
            withClient: self.client
        )
    }
}
