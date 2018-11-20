import Foundation
import StitchCoreSDK
import MongoMobile
import StitchCoreLocalMongoDBService

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

public final class CoreRemoteMongoClientFactory {
    public static let shared = CoreRemoteMongoClientFactory()
    private var syncInstances = [String: CoreRemoteMongoClient]()

    private init() {
    }

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
