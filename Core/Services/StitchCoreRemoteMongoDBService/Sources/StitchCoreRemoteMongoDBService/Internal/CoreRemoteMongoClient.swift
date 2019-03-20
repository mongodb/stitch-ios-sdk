import Foundation
import StitchCoreSDK
import MongoSwift
import StitchCoreLocalMongoDBService

public class CoreRemoteMongoClient: StitchServiceBinder {
    internal var dataSynchronizer: DataSynchronizer!

    private let appInfo: StitchAppClientInfo
    private let service: CoreStitchServiceClient
    private var lastActiveUserId: String?
    private var collections: [WeakReference<AnyClosable>] = []

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
                                            withClient: self)
    }

    private func onAuthEvent(_ authEvent: AuthRebindEvent) {
        switch authEvent {
        case .userRemoved(let removedUser):
            let userId = removedUser.id
            let key = appInfo.clientAppID + "/\(userId)"
            try? CoreLocalMongoDBService.shared.deleteDatabase(
                withKey: key,
                withDBPath: "\(appInfo.dataDirectory.path)/local_mongodb/0/\(key)")
        case .activeUserChanged(let currentActiveUser, _):
            if lastActiveUserId != currentActiveUser?.id {
                self.lastActiveUserId = currentActiveUser?.id
                if currentActiveUser != nil {
                    self.collections = self.collections.compactMap {
                        guard let ref = $0.reference else {
                            return nil
                        }
                        ref.close()
                        return $0
                    }
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

    internal func register(closable: AnyClosable) {
        self.collections.append(WeakReference(closable))
    }
}
