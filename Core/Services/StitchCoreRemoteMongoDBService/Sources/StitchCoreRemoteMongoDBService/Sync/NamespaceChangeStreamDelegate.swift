import Foundation
import MongoSwift
import StitchCoreSDK

let retrySleepSeconds: UInt32 = 5

class NamespaceChangeStreamDelegate: SSEStreamDelegate, NetworkStateDelegate {
    private let namespace: MongoNamespace
    private let service: CoreStitchServiceClient
    private let networkMonitor: NetworkMonitor
    private let authMonitor: AuthMonitor
    private let nsConfig: NamespaceSynchronization
    private let holdingSemaphore = DispatchSemaphore(value: 0)

    private var eventsKeyedQueue = [HashableBSONValue: ChangeEvent<Document>]()
    private var streamDelegates = Set<SSEStreamDelegate>()

    private var stream: RawSSEStream? = nil
    private var streamWorkItem: DispatchWorkItem? = nil

    private lazy var tag = "ns_changestream_listener_\(namespace)"
    private lazy var logger = Log.init(tag: tag)
    private lazy var eventQueueLock = ReadWriteLock.init(label: tag)
    private lazy var queue = DispatchQueue(label: self.tag)

    var state: SSEStreamState {
        return stream?.state ?? .closed
    }

    init(namespace: MongoNamespace,
         config: NamespaceSynchronization,
         service: CoreStitchServiceClient,
         networkMonitor: NetworkMonitor,
         authMonitor: AuthMonitor) throws {
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
        self.stop()
        streamDelegates.forEach({$0.on(stateChangedFor: .closed)})
    }

    func start() {
        if stream != nil {
            self.stop()
        }
        
        self.streamWorkItem = DispatchWorkItem { [weak self] in
            repeat {
                guard let self = self else {
                    return
                }

                if self.state != .open && self.state != .opening {
                    do {
                        let isOpening = try self.openStream()
                        if !isOpening {
                            sleep(retrySleepSeconds)
                        }
                    } catch {
                        self.logger.e("NamespaceChangeStreamRunner::run error happened while opening stream: \(error)");
                        return
                    }
                } else {
                    self.holdingSemaphore.wait()
                }
            } while self?.networkMonitor.state == .connected &&
                self?.streamWorkItem?.isCancelled == false
        }
        queue.async(execute: self.streamWorkItem!)
    }

    /**
     Open the event stream.
     */
    private func openStream() throws -> Bool {
        return try eventQueueLock.write {
            logger.i("stream START")
            guard networkMonitor.state == .connected else {
                logger.i("stream END - Network disconnected")
                return false
            }
            guard authMonitor.isLoggedIn else {
                logger.i("stream END - Logged out")
                return false
            }

            let idsToWatch = nsConfig.map({ $0.documentId.value })
            guard !idsToWatch.isEmpty else {
                logger.i("stream END - No synchronized documents")
                return false
            }

            self.stream = try service.streamFunction(
                withName: "watch",
                withArgs: [
                    ["database": namespace.databaseName,
                     "collection": namespace.collectionName,
                     "ids": idsToWatch] as Document
                ],
                delegate: self)

            return true
        }
    }

    func stop() {
        eventQueueLock.write {
            logger.i("stream STOP")
            if let stream = stream {
                guard stream.state != .closing, stream.state != .closed else {
                    logger.i("stream END - stream is \(stream.state)")
                    return
                }
            }

            self.stream?.close()
            self.streamWorkItem?.cancel()
            holdingSemaphore.signal()
        }
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
        do {
            try eventQueueLock.write {
                guard let changeEvent: ChangeEvent<Document> = try event.decodeStitchSSE(),
                    let id = changeEvent.documentKey["_id"] else {
                        logger.e("invalid change event found!")
                        return
                }

                logger.d("event found: op=\(changeEvent.operationType) id=\(id)")

                streamDelegates.forEach({$0.on(newEvent: event)})
                self.eventsKeyedQueue[HashableBSONValue(id)] = changeEvent
            }
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
            logger.d("stream OPEN")
            try? nsConfig.set(stale: true)
        case .closed:
            // if the stream has been closed,
            // deallocate the remaining stream
            logger.d("stream CLOSED")
            stream = nil
            holdingSemaphore.signal()
            // if a restart has been commanded,
            // start again
        default:
            logger.d("stream \(state)")
        }
        
        streamDelegates.forEach({$0.on(stateChangedFor: state)})
    }

    override func on(error: Error) {
        logger.e(error.localizedDescription)
    }

    func dequeueEvents() -> [HashableBSONValue: ChangeEvent<Document>] {
        return eventQueueLock.write {
            var events = [HashableBSONValue: ChangeEvent<Document>]()
            while let (key, value) = eventsKeyedQueue.popFirst() {
                events[key] = value
            }
            return events
        }
    }

    func unprocessedEvent(for documentId: BSONValue) -> ChangeEvent<Document>? {
        return eventQueueLock.write {
            return self.eventsKeyedQueue.removeValue(forKey: HashableBSONValue(documentId))
        }
    }
}
