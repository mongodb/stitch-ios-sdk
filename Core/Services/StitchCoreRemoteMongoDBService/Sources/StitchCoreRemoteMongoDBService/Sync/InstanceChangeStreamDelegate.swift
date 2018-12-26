import Foundation
import StitchCoreSDK

class InstanceChangeStreamDelegate {
    /// The configuration for this instance
    private var instanceConfig: InstanceSynchronization
    /// The service client for network calls
    private let service: CoreStitchServiceClient
    /// The network monitor that will notify us of network state
    private let networkMonitor: NetworkMonitor
    /// The auth monitor that will notify us of auth state
    private let authMonitor: AuthMonitor
    /// A mapping of of change stream delegates keyed on namespaces
    private var namespaceToStreamDelegates = [MongoNamespace: NamespaceChangeStreamDelegate]()
    
    init(instanceConfig: InstanceSynchronization,
         service: CoreStitchServiceClient,
         networkMonitor: NetworkMonitor,
         authMonitor: AuthMonitor) {
        self.instanceConfig = instanceConfig
        self.service = service
        self.networkMonitor = networkMonitor
        self.authMonitor = authMonitor
    }

    deinit {
        self.stop()
    }
    
    /**
     Append a namespace to this instance, initing a NamespaceChangeStreamDelegate
     in the process.

     - parameter namespace: the namespace to add a listener for
     */
    func append(namespace: MongoNamespace) {
        guard let nsConfig = instanceConfig[namespace],
            namespaceToStreamDelegates[namespace] == nil else {
            return
        }

        self.namespaceToStreamDelegates[namespace] = try? NamespaceChangeStreamDelegate(
            namespace: namespace,
            config: nsConfig,
            service: service,
            networkMonitor: networkMonitor,
            authMonitor: authMonitor)
    }

    func remove(namespace: MongoNamespace) {
        self.namespaceToStreamDelegates.removeValue(forKey: namespace)
    }

    func start() {
        self.namespaceToStreamDelegates.forEach({$0.value.start()})
    }

    func start(namespace: MongoNamespace) {
        self.namespaceToStreamDelegates[namespace]?.start()
    }

    func stop() {
        self.namespaceToStreamDelegates.forEach({ $0.value.stop() })
    }

    func stop(namespace: MongoNamespace) {
        self.namespaceToStreamDelegates[namespace]?.stop()
    }

    subscript(namespace: MongoNamespace) -> NamespaceChangeStreamDelegate? {
        return namespaceToStreamDelegates[namespace]
    }
}
