import Foundation
import StitchCoreSDK

public class CoreRemoteMongoClient {
    private let service: CoreStitchServiceClient
    
    public init(withService service: CoreStitchServiceClient) {
        self.service = service
    }
    
    /**
     * Gets a `CoreRemoteMongoDatabase` instance for the given database name.
     *
     * - parameter name: the name of the database to retrieve
     */
    public func db(_ name: String) -> CoreRemoteMongoDatabase {
        return CoreRemoteMongoDatabase.init(withName: name, withService: service)
    }
}
