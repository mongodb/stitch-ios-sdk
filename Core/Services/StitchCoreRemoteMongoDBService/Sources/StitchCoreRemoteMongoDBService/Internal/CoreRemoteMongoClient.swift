import Foundation
import StitchCoreSDK
import MongoSwift
import StitchCoreLocalMongoDBService

public class CoreRemoteMongoClient: StitchServiceBinder {
    private let appInfo: StitchAppClientInfo
    private let service: CoreStitchServiceClient
    private var dataSynchronizer: DataSynchronizer!
    private var lastActiveUserId: String?

    internal init(withService service: CoreStitchServiceClient,
                  withInstanceKey instanceKey: String,
                  withAppInfo appInfo: StitchAppClientInfo) throws {
        self.service = service
        self.appInfo = appInfo
        self.dataSynchronizer = try DataSynchronizer.init(
            instanceKey: instanceKey,
            service: service,
            remoteClient: self,
            appInfo: appInfo)
        self.service.bind(binder: self)
        self.lastActiveUserId = appInfo.authMonitor.activeUserId
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

    private func onAuthEvent(_ authEvent: AuthRebindEvent) {
        switch authEvent {
        case .userRemoved(let removedUser):
            let userId = removedUser.id
            let key = appInfo.clientAppID + "/\(userId)"
            try? CoreLocalMongoDBService.shared.deleteDatabase(
                withKey: key,
                withDBPath: "\(appInfo.dataDirectory.path)/local_mongodb/0/\(key)")
        case .activeUserChanged(let currentActiveUser, let previousActiveUser):
            if lastActiveUserId != appInfo.authMonitor.activeUserId {
                self.lastActiveUserId = appInfo.authMonitor.activeUserId
                if currentActiveUser != nil {
                    self.dataSynchronizer.reinitialize(appInfo: appInfo)
                } else {
                    self.dataSynchronizer.stop()
                }
            }
        default:
            break
        }
    }

    public func onRebindEvent(_ rebindEvent: RebindEvent) {
        switch rebindEvent.type {
        case .authEvent:
            guard let authEvent = rebindEvent as? AuthRebindEvent else {
                return
            }
            onAuthEvent(authEvent)
        }
    }
}
