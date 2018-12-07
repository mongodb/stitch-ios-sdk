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
    private var streamDelegates = [SSEStreamDelegate]()

    private var stream: RawSSEStream? = nil
    private lazy var tag = "NSChangeStreamListener-\(namespace.description)"
    private lazy var logger = Log.init(tag: tag)

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
    }

    /**
     Open the event stream
      - returns: true if successfully opened, false if not
     */
    func start() throws {
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
        logger.i("stream STOP")
        self.stream?.close()
    }

    func add(streamDelegate: SSEStreamDelegate) {
        streamDelegates.append(streamDelegate)
    }

    func on(stateChangedFor state: NetworkState) {
        self.stop()
    }

    override func on(newEvent event: RawSSE) {
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
            logger.d("stream OPEN")
        case .closed:
            logger.d("stream CLOSED")
        }
        streamDelegates.forEach({$0.on(stateChangedFor: state)})
    }

    override func on(error: Error) {
        logger.e(error.localizedDescription)
    }

    func dequeueEvents() -> [HashableBSONValue: ChangeEvent<Document>] {
        var events = [HashableBSONValue: ChangeEvent<Document>]()
        while let (key, value) = eventsKeyedQueue.popFirst() {
            events[key] = value
        }
        return events
    }

    func unprocessedEvent(for documentId: BSONValue) -> ChangeEvent<Document>? {
        return self.eventsKeyedQueue.removeValue(forKey: HashableBSONValue(documentId))
    }
}
