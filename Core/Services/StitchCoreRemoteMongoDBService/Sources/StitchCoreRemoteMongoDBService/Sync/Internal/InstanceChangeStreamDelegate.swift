import Foundation
import MongoSwift
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
    private let instanceLock = ReadWriteLock(label: "instance_\(ObjectId())")

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
        instanceLock.write {
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
    }

    func remove(namespace: MongoNamespace) {
        _ = instanceLock.write {
            self.namespaceToStreamDelegates.removeValue(forKey: namespace)
        }
    }

    func start() {
        instanceLock.write {
            self.namespaceToStreamDelegates.forEach({$0.value.start()})
        }
    }

    func start(namespace: MongoNamespace) {
        instanceLock.write {
            self.namespaceToStreamDelegates[namespace]?.start()
        }
    }

    func stop() {
        instanceLock.write {
            self.namespaceToStreamDelegates.forEach {
                let (_, nsDel) = $0
                nsDel.eventQueueLock.write { nsDel.stop() }
            }
        }
    }

    func stop(namespace: MongoNamespace) {
        instanceLock.write {
            guard let nsDel = self.namespaceToStreamDelegates[namespace] else {
                return
            }

            nsDel.eventQueueLock.write { nsDel.stop() }
        }
    }

    var allStreamsAreOpen: Bool {
        return instanceLock.write {
            for (_, streamer) in self.namespaceToStreamDelegates where streamer.state != .open {
                return false
            }
            return true
        }
    }

    subscript(namespace: MongoNamespace) -> NamespaceChangeStreamDelegate? {
        return instanceLock.read {
            return namespaceToStreamDelegates[namespace]
        }
    }
}
