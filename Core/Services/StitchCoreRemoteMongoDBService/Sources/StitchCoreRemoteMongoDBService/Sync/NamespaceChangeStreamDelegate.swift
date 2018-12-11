import Foundation
import MongoSwift
import StitchCoreSDK

class NamespaceChangeStreamDelegate: SSEStreamDelegate, NetworkStateDelegate {
    private let namespace: MongoNamespace
    private let service: CoreStitchServiceClient
    private let networkMonitor: NetworkMonitor
    private let authMonitor: AuthMonitor
    private let nsConfig: NamespaceSynchronization
    private var eventsKeyedQueue = [HashableBSONValue: ChangeEvent<Document>]()
    private var streamDelegates = Set<SSEStreamDelegate>()

    private var stream: RawSSEStream? = nil
    private lazy var tag = "NSChangeStreamListener-\(namespace.description)"
    private lazy var logger = Log.init(tag: tag)
    private lazy var eventQueueLock = ReadWriteLock()

    init(namespace: MongoNamespace,
         config: inout NamespaceSynchronization,
         service: CoreStitchServiceClient,
         networkMonitor: NetworkMonitor,
         authMonitor: AuthMonitor) {
        self.namespace = namespace
        self.nsConfig = config
        self.service = service
        self.networkMonitor = networkMonitor
        self.authMonitor = authMonitor
        super.init()
        networkMonitor.add(networkStateDelegate: self)
    }

    /**
     Open the event stream.
     */
    func start() throws {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        logger.i("stream START")
        if let stream = stream {
            guard stream.state != .opening else {
                logger.i("stream END - stream is \(stream.state)")
                return
            }
        }

        guard networkMonitor.state == .connected else {
            logger.i("stream END - Network disconnected")
            return
        }
        guard authMonitor.isLoggedIn else {
            logger.i("stream END - Logged out")
            return
        }

        let idsToWatch = nsConfig.map({ $0.documentId.value })
        guard !idsToWatch.isEmpty else {
            logger.i("stream END - No synchronized documents")
            return
        }

        self.stream = try service.streamFunction(
            withName: "watch",
            withArgs: [
                ["database": namespace.databaseName,
                 "collection": namespace.collectionName,
                 "ids": idsToWatch] as Document
            ],
            delegate: self)
    }

    func stop() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        logger.i("stream STOP")
        if let stream = stream {
            guard stream.state != .closing, stream.state != .closed else {
                logger.i("stream END - stream is \(stream.state)")
                return
            }
        }
        self.stream?.close()
    }

    func add(streamDelegate: SSEStreamDelegate) {
        streamDelegates.insert(streamDelegate)
    }

    func on(stateChangedFor state: NetworkState) {
        if state == .disconnected, stream?.state != .closing {
            self.stop()
        }
    }

    override func on(newEvent event: RawSSE) {
        eventQueueLock.writeLock()
        defer { eventQueueLock.unlock() }

        do {

            guard let changeEvent: ChangeEvent<Document> = try event.decodeStitchSSE(),
                let id = changeEvent.documentKey["_id"] else {
                return
            }

            logger.d("event found: op=\(changeEvent.operationType) id=\(id)")

            streamDelegates.forEach({$0.on(newEvent: event)})
            self.eventsKeyedQueue[HashableBSONValue(id)] = changeEvent

        } catch {
            logger.e("error occurred: err=\(error.localizedDescription)")
            self.stop()
        }
    }

    override func on(stateChangedFor state: SSEStreamState) {
        switch state {
        case .open:
            for var docConfig in nsConfig {
                docConfig.isStale = true
            }
            logger.d("stream OPEN")
        case .closed:
            logger.d("stream CLOSED")
        default:
            logger.d("stream \(state)")
        }

        streamDelegates.forEach({$0.on(stateChangedFor: state)})
    }

    override func on(error: Error) {
        logger.e(error.localizedDescription)
    }

    func dequeueEvents() -> [HashableBSONValue: ChangeEvent<Document>] {
        eventQueueLock.writeLock()
        defer { eventQueueLock.unlock() }

        var events = [HashableBSONValue: ChangeEvent<Document>]()
        while let (key, value) = eventsKeyedQueue.popFirst() {
            events[key] = value
        }
        return events
    }

    func unprocessedEvent(for documentId: BSONValue) -> ChangeEvent<Document>? {
        eventQueueLock.writeLock()
        defer { eventQueueLock.unlock() }

        return self.eventsKeyedQueue.removeValue(forKey: HashableBSONValue(documentId))
    }
}
