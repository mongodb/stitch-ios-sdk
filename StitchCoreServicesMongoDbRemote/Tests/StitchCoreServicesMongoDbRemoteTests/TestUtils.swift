import Foundation
import MongoSwift
import StitchCore
import StitchCoreMocks
@testable import StitchCoreServicesMongoDbRemote

final class TestUtils {
    
    static func getClient() -> CoreRemoteMongoClient {
        let service = MockCoreStitchService()
        return CoreRemoteMongoClient.init(withService: service)
    }
    
    static func getDatabase(withName name: String) -> CoreRemoteMongoDatabase {
        let service = MockCoreStitchService()
        return CoreRemoteMongoDatabase.init(withName: name, withService: service)
    }
    
    static func getDatabase() -> CoreRemoteMongoDatabase {
        return self.getDatabase(withName: "dbName1")
    }
    
    static func getCollection(withName name: String) -> CoreRemoteMongoCollection<Document> {
        let routes = StitchAppRoutes.init(clientAppId: "foo").serviceRoutes
        let requestClient = MockStitchAuthRequestClient()
        let service = SpyCoreStitchService.init(requestClient: requestClient, routes: routes, serviceName: nil)
        
        let client = CoreRemoteMongoClient.init(withService: service)
        let db = client.db("dbName1")
        return db.collection(name)
    }
    
    static func getCollection() -> CoreRemoteMongoCollection<Document> {
        return getCollection(withName: "collName1")
    }
    
    static func getCollection(withClient client: CoreRemoteMongoClient) -> CoreRemoteMongoCollection<Document> {
        return client.db("dbName1").collection("collName1")
    }
}
