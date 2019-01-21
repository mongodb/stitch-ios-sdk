import Foundation
import MongoSwift
import StitchCoreSDK

let retrySleepSeconds: UInt32 = 5
let longRetry: UInt32 = 10

class NamespaceChangeStreamDelegate: SSEStreamDelegate, NetworkStateDelegate {
    private let namespace: MongoNamespace
    private let service: CoreStitchServiceClient
    private let networkMonitor: NetworkMonitor
    private let authMonitor: AuthMonitor
    private let nsConfig: NamespaceSynchronization
    private var holdingSemaphore = DispatchSemaphore(value: 0)

    private var eventsKeyedQueue = [AnyBSONValue: ChangeEvent<Document>]()
    private var streamDelegates = Set<SSEStreamDelegate>()

    private var stream: RawSSEStream?

    private lazy var tag = "ns_changestream_listener_\(namespace)_\(ObjectId())"
    private lazy var logger = Log.init(tag: tag)
    private lazy var queue = DispatchQueue(label: self.tag)

    internal lazy var eventQueueLock = ReadWriteLock.init(label: tag)

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
        eventQueueLock.write { self.stop() }
        streamDelegates.forEach({$0.on(stateChangedFor: .closed)})
    }

    func start() {
        eventQueueLock.write {
            self.stop()

            queue.async { [weak self] in
                repeat {
                    guard self != nil, self?.state != .open else {
                        return
                    }

                    if self?.state != .open && self?.state != .opening  && self?.state != .closing {
                        do {
                            let isOpening = try self?.openStream() ?? true
                            if !isOpening {
                                sleep(retrySleepSeconds)
                            } else {
                                return
                            }
                        } catch {
                            self?.logger.e("error happened while opening stream: \(error)")
                            return
                        }
                    }
                } while self?.networkMonitor.state == .connected

                self?.logger.d("stream WORK DONE")
            }
        }
    }

    /**
     Open the event stream.
     */
    private func openStream() throws -> Bool {
        logger.i("stream START")
        guard networkMonitor.state == .connected else {
            logger.i("stream END - Network disconnected")
            return false
        }
        guard authMonitor.isLoggedIn else {
            logger.i("stream END - Logged out")
            return false
        }

        guard state != .opening else {
            logger.i("stream END - Already opening")
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

    func stop() {
        eventQueueLock.assertWriteLocked()
        logger.i("stream STOP")

        guard let stream = stream,
            stream.state != .closing, stream.state != .closed else {
            logger.i("stream END - stream is closed")
            return
        }

        stream.close()
    }

    func add(streamDelegate: SSEStreamDelegate) {
        streamDelegates.insert(streamDelegate)
    }

    func on(stateChangedFor state: NetworkState) {
        if state == .disconnected && stream?.state != .closing {
            eventQueueLock.write { self.stop() }
        }
    }

    override func on(newEvent event: RawSSE) {
        eventQueueLock.write {
            do {
                guard let changeEvent: ChangeEvent<Document> = try event.decodeStitchSSE(),
                    let id = changeEvent.documentKey["_id"] else {
                        logger.e("invalid change event found!")
                        return
                }

                logger.d("event found: op=\(changeEvent.operationType) id=\(id)")

                streamDelegates.forEach({$0.on(newEvent: event)})
                self.eventsKeyedQueue[AnyBSONValue(id)] = changeEvent
            } catch {
                logger.e("error occurred when decoding event from stream: err=\(error.localizedDescription)")
                self.stop()
            }
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
        default:
            logger.d("stream \(state)")
        }

        streamDelegates.forEach({$0.on(stateChangedFor: state)})
    }

    override func on(error: Error) {
        logger.e(error.localizedDescription)
    }

    func dequeueEvents() -> [AnyBSONValue: ChangeEvent<Document>] {
        return eventQueueLock.write {
            var events = [AnyBSONValue: ChangeEvent<Document>]()
            while let (key, value) = eventsKeyedQueue.popFirst() {
                events[key] = value
            }
            return events
        }
    }

    func unprocessedEvent(for documentId: BSONValue) -> ChangeEvent<Document>? {
        return eventQueueLock.write {
            return self.eventsKeyedQueue.removeValue(forKey: AnyBSONValue(documentId))
        }
    }
}
