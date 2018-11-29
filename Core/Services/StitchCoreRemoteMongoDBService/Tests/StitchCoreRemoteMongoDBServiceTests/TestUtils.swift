import Foundation
import MongoSwift
import StitchCoreSDK
import StitchCoreSDKMocks
@testable import StitchCoreRemoteMongoDBService

final class TestUtils {

    static func getClient() -> CoreRemoteMongoClient {
        let service = MockCoreStitchServiceClient()
        return CoreRemoteMongoClient.init(withService: service)
    }

    static func getDatabase(withName name: String) -> CoreRemoteMongoDatabase {
        let service = MockCoreStitchServiceClient()
        return CoreRemoteMongoDatabase.init(withName: name, withService: service)
    }

    static func getDatabase() -> CoreRemoteMongoDatabase {
        return self.getDatabase(withName: "dbName1")
    }

    static func getCollection(withName name: String) -> CoreRemoteMongoCollection<Document> {
        let routes = StitchAppRoutes.init(clientAppID: "foo").serviceRoutes
        let requestClient = MockStitchAuthRequestClient()
        let service = SpyCoreStitchServiceClient.init(requestClient: requestClient, routes: routes, serviceName: nil)

        let client = CoreRemoteMongoClient.init(withService: service)
        let database = client.db("dbName1")
        return database.collection(name)
    }

    static func getCollection() -> CoreRemoteMongoCollection<Document> {
        return getCollection(withName: "collName1")
    }

    static func getCollection(withClient client: CoreRemoteMongoClient) -> CoreRemoteMongoCollection<Document> {
        return client.db("dbName1").collection("collName1")
    }
}
