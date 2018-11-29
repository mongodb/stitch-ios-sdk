import Foundation
import StitchCoreSDK
import MongoSwift

public class CoreRemoteMongoClient {
    private let service: CoreStitchServiceClient
    private let dataSynchronizer: DataSynchronizer

    internal init(withService service: CoreStitchServiceClient,
                  withInstanceKey instanceKey: String,
                  withLocalClient localClient: MongoClient,
                  withNetworkMonitor networkMonitor: NetworkMonitor,
                  withAuthMonitor authMonitor: AuthMonitor) throws {
        self.service = service
        self.dataSynchronizer = try DataSynchronizer.init(
            instanceKey: instanceKey,
            service: service,
            localClient: localClient,
            remoteClient: self,
            networkMonitor: networkMonitor,
            authMonitor: authMonitor)
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
