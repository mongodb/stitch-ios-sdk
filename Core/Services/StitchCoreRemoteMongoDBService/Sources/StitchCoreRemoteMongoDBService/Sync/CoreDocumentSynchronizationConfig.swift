import Foundation
import MongoMobile
import MongoSwift

private func getDocFilter(namespace: MongoNamespace,documentId: AnyBSONValue) -> Document {
    return [
        CoreDocumentSynchronizationConfig.CodingKeys.namespace.rawValue: namespace.description,
        CoreDocumentSynchronizationConfig.CodingKeys.documentId.rawValue: documentId.value
    ]
}

struct CoreDocumentSynchronizationConfig: Codable {
    fileprivate enum CodingKeys: String, CodingKey {
        case namespace, documentId, lastUncommittedChangeEvent
        case lastResolution, lastKnownRemoteVersion, isStale, isPaused
    }
    private let docsColl: MongoCollection<CoreDocumentSynchronizationConfig>?
    private let namespace: MongoNamespace
    private let documentId: AnyBSONValue
    private let docLock: ReadWriteLock
    private let lastUncommittedChangeEvent: ChangeEvent<Document>?
    private let lastResolution: Int64
    private let lastKnownRemoteVersion: Document
    private var _isStale: Bool = false
    var isStale: Bool {
        get {
            return _isStale
        }
        set(value) {
            docLock.writeLock.lock()
            defer { docLock.writeLock.unlock() }
            let _ = try? docsColl?.updateOne(
                filter: getDocFilter(namespace: namespace, documentId: documentId),
                update: [
                    CodingKeys.isStale.rawValue: value
                ])
            _isStale = value
        }
    }
    private let isPaused: Bool

    var hasUncommittedWrites: Bool {
        get {
            return lastUncommittedChangeEvent != nil
        }
    }

    init(from decoder: Decoder) throws {
        self.docsColl = nil
        self.docLock = ReadWriteLock()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.namespace = try container.decode(MongoNamespace.self, forKey: .namespace)
        self.documentId = try container.decode(AnyBSONValue.self, forKey: .documentId)
        self.lastUncommittedChangeEvent = try container.decode(ChangeEvent<Document>.self,
                                                               forKey: .lastUncommittedChangeEvent)
        self.lastResolution = try container.decode(Int64.self, forKey: .lastResolution)
        self.lastKnownRemoteVersion = try container.decode(Document.self,
                                                           forKey: .lastKnownRemoteVersion)
        self._isStale = try container.decode(Bool.self, forKey: .isStale)
        self.isPaused = try container.decode(Bool.self, forKey: .isPaused)
    }

    func encode(to encoder: Encoder) throws {

    }
}
