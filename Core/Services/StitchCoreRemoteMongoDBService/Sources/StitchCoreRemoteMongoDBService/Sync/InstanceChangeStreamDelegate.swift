import Foundation
import StitchCoreSDK

class InstanceChangeStreamDelegate {
    private var instanceConfig: InstanceSynchronization
    private let service: CoreStitchServiceClient
    private let networkMonitor: NetworkMonitor
    private let authMonitor: AuthMonitor
    private var namespaceToStreamDelegates = [MongoNamespace: NamespaceChangeStreamDelegate]()
    
    init(instanceConfig: InstanceSynchronization,
         service: CoreStitchServiceClient,
         networkMonitor: NetworkMonitor,
         authMonitor: AuthMonitor) {
        self.instanceConfig = instanceConfig;
        self.service = service;
        self.networkMonitor = networkMonitor;
        self.authMonitor = authMonitor;
    }

    func append(namespace: MongoNamespace) {
        guard var nsConfig = instanceConfig[namespace] else {
            return
        }

        self.namespaceToStreamDelegates[namespace] = NamespaceChangeStreamDelegate(
            namespace: namespace,
            config: &nsConfig,
            service: service,
            networkMonitor: networkMonitor,
            authMonitor: authMonitor)
    }

    func remove(namespace: MongoNamespace) {
        self.namespaceToStreamDelegates.removeValue(forKey: namespace)
    }

    func start() throws {
        try self.namespaceToStreamDelegates.forEach({try $0.value.start()})
    }

    func start(namespace: MongoNamespace) throws {
        try self.namespaceToStreamDelegates[namespace]?.start()
    }

    func stop(namespace: MongoNamespace) throws {
        try self.namespaceToStreamDelegates[namespace]?.stop()
    }

    subscript(namespace: MongoNamespace) -> NamespaceChangeStreamDelegate? {
        return namespaceToStreamDelegates[namespace]
    }
}
