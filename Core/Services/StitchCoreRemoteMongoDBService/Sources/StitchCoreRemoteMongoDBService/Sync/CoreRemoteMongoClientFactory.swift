import Foundation
import StitchCoreSDK
import MongoMobile
import StitchCoreLocalMongoDBService

/**
 Get a new MongoClient for sync purposes.

 - parameter appInfo: info to be keyed on for storage purposes
 - parameter serviceName: name of the local mdb service
 - returns: a local mongo client
*/
private func syncMongoClient(
    withAppInfo appInfo: StitchAppClientInfo,
    withServiceName serviceName: String
) throws -> MongoClient {
    let dataDir = appInfo.dataDirectory
    let instanceKey = "\(appInfo.clientAppID)-\(dataDir)_sync_\(serviceName)"
    let dbPath = "\(dataDir)/\(appInfo.clientAppID)/sync_mongodb_\(serviceName)/0/"

    return try CoreLocalMongoDBService.client(withKey: instanceKey,
                                              withDBPath: dbPath)
}

/**
 Factory that produces new core local mongo clients.

 Initialization must be internalized so that we can maintain
 strong references to sync clients.
*/
public final class CoreRemoteMongoClientFactory {
    /// Singleton instance of this factory
    public static let shared = CoreRemoteMongoClientFactory()
    /// References to CoreRemoteMongoClients keyed on the instance key
    private var syncInstances = [String: CoreRemoteMongoClient]()

    private init() {
    }

    /**
     Get a new remote mongo client.
     - parameter service: mongodb service connected with this client
     - parameter appInfo: appInfo to use for keying
     - returns: a new CoreRemoteMongoClient
     */
    public func client(withService service: CoreStitchServiceClient,
                       withAppInfo appInfo: StitchAppClientInfo) throws -> CoreRemoteMongoClient {
        let instanceKey = "\(appInfo.clientAppID)-\(service.name)"
        if let instance = syncInstances[instanceKey] {
            return instance
        }

        let syncClient = try CoreRemoteMongoClient.init(
            withService: service,
            withInstanceKey: instanceKey,
            withLocalClient: try syncMongoClient(withAppInfo: appInfo,
                                                 withServiceName: service),
            withNetworkMonitor: appInfo.networkMonitor,
            withAuthMonitor: appInfo.authMonitor)
        syncInstances[instanceKey] = syncClient
        return syncClient
    }
}
