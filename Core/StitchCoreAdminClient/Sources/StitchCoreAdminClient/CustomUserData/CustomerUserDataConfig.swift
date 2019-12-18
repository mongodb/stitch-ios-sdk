import Foundation
import MongoSwift

public struct CustomUserConfigData: Codable {
    private enum CodingKeys: String, CodingKey {
        case mongoServiceId = "mongo_service_id"
        case databaseName = "database_name"
        case collectionName = "collection_name"
        case userIdField = "user_id_field"
        case enabled = "enabled"
    }

    let mongoServiceId: String
    let databaseName: String
    let collectionName: String
    let userIdField: String
    let enabled: Bool

    public init(mongoServiceId: String,
                databaseName: String,
                collectionName: String,
                userIdField: String,
                enabled: Bool) {
        self.mongoServiceId = mongoServiceId
        self.databaseName = databaseName
        self.collectionName = collectionName
        self.userIdField = userIdField
        self.enabled = enabled
    }
}
