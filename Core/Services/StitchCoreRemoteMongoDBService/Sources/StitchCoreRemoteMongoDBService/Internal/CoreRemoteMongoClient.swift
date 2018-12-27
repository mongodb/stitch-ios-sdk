import Foundation
import StitchCoreSDK
import MongoSwift

public class CoreRemoteMongoClient {
    private let service: CoreStitchServiceClient
    private var dataSynchronizer: DataSynchronizer!

    internal init(withService service: CoreStitchServiceClient,
                  withInstanceKey instanceKey: String,
                  withAppInfo appInfo: StitchAppClientInfo) throws {
        self.service = service
        self.dataSynchronizer = try DataSynchronizer.init(
            instanceKey: instanceKey,
            service: service,
            remoteClient: self,
            appInfo: appInfo)
    }

    /**
     * Gets a `CoreRemoteMongoDatabase` instance for the given database name.
     *
     * - parameter name: the name of the database to retrieve
     */
    public func db(_ name: String) -> CoreRemoteMongoDatabase {
        return CoreRemoteMongoDatabase.init(withName: name,
                                            withService: service,
                                            withDataSynchronizer: dataSynchronizer)
    }
}
