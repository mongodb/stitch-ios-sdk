import Foundation
import MongoSwift
import StitchCoreSDK

class NamespaceChangeStreamDelegate: SSEStreamDelegate, NetworkStateDelegate {
    private enum Command {
        case restart
    }

    private let namespace: MongoNamespace
    private let service: CoreStitchServiceClient
    private let networkMonitor: NetworkMonitor
    private let authMonitor: AuthMonitor
    private let nsConfig: NamespaceSynchronization
    private var eventsKeyedQueue = [HashableBSONValue: ChangeEvent<Document>]()
    private var streamDelegates = Set<SSEStreamDelegate>()

    private var stream: RawSSEStream? = nil
    private var command: Command? = nil

    private lazy var tag = "NSChangeStreamListener-\(namespace.description)"
    private lazy var logger = Log.init(tag: tag)
    private lazy var eventQueueLock = ReadWriteLock()
    var state: SSEStreamState {
        return stream?.state ?? .closed
    }

    init(namespace: MongoNamespace,
         config: NamespaceSynchronization,
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

    deinit {
        logger.i("stream DEINITIALIZED")
        streamDelegates.forEach({$0.on(stateChangedFor: .closed)})
    }

    /**
     Open the event stream.
     */
    func start() throws {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        logger.i("stream START")
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

        if let stream = stream {
            command = .restart
            logger.i("stream RESTART - stream was \(stream.state)")
            self.stop()
        } else {
            self.stream = try service.streamFunction(
                withName: "watch",
                withArgs: [
                    ["database": namespace.databaseName,
                     "collection": namespace.collectionName,
                     "ids": idsToWatch] as Document
                ],
                delegate: self)
        }
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
            logger.e("error occurred when decoding event from stream: err=\(error.localizedDescription)")

            self.stop()
        }
    }

    override func on(stateChangedFor state: SSEStreamState) {
        switch state {
        case .open:
            // if the stream has been opened,
            // mark all of the configs in this namespace
            // as stale so we know to check for stale docs
            // during a sync pass
            self.command = nil
            try? nsConfig.set(stale: true)
            logger.d("stream OPEN")
        case .closed:
            // if the stream has been closed,
            // deallocate the remaining stream
            logger.d("stream CLOSED")
            stream = nil
            // if a restart has been commanded,
            // start again
            if command == .restart {
                try? start()
            }
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
