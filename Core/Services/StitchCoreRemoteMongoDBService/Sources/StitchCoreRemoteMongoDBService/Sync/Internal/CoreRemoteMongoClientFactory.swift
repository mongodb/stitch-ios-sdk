import Foundation
import StitchCoreSDK
import MongoMobile
import StitchCoreLocalMongoDBService

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
        // Default to "mongodb-local" for now. Unclear if local service
        // will be able to take on its own name.
        let instanceKey = "\(appInfo.clientAppID)-\(service.serviceName ?? "mongodb-local")"
        if let instance = syncInstances[instanceKey] {
            return instance
        }

        let syncClient = try CoreRemoteMongoClient.init(
            withService: service,
            withInstanceKey: instanceKey,
            withAppInfo: appInfo)
        syncInstances[instanceKey] = syncClient
        return syncClient
    }
}
