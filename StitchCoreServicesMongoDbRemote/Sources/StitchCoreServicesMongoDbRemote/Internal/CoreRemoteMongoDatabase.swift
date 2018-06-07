import Foundation
import MongoSwift
import StitchCore

public class CoreRemoteMongoDatabase {
    /**
     * The name of this database.
     */
    public let name: String
    
    private let service: CoreStitchServiceClient
    
    public init(withName name: String,
                withService service: CoreStitchServiceClient) {
        self.name = name
        self.service = service
    }
    
    /**
     * Gets a collection.
     *
     * - parameter name: the name of the collection to return
     * - returns: the collection
     */
    public func collection(_ collectionName: String) -> CoreRemoteMongoCollection<Document> {
        return self.collection(collectionName, withDocumentType: Document.self)
    }
    
    /**
     * Gets a collection with a specific default document type.
     *
     * - parameter name: the name of the collection to return
     * - parameter withDocumentType: the default class to cast any documents returned from the database into.
     * - returns: the collection
     */
    public func collection<T: Codable>(_ collectionName: String, withDocumentType type: T.Type) -> CoreRemoteMongoCollection<T> {
        return CoreRemoteMongoCollection<T>.init(
            withName: collectionName,
            withDatabaseName: self.name,
            withService: self.service
        )
    }
}
