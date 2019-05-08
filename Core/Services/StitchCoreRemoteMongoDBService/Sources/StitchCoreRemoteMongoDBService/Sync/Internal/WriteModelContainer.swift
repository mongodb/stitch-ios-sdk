//
//  WriteModelContainer.swift
//  StitchCoreRemoteMongoDBService
//
//  Created by Douglas Kaminsky on 4/16/19.
//

import MongoSwift
import StitchCoreSDK

/*
 * Abstract structure for collecting writes and applying them at a later time.
 */
class WriteModelContainer<CollectionT, DocumentT: Codable> {
    fileprivate let collection: CollectionT
    fileprivate var bulkWriteModels = [WriteModelWrapper<DocumentT>]()
    fileprivate var logger: Log!

    fileprivate init(_ collection: CollectionT, _ dataSynchronizerLogTag: String) {
        self.collection = collection
        self.logger = Log.init(tag: "writeModelContainer-\(dataSynchronizerLogTag)")
    }

    func add(_ writeOrNil: WriteModelWrapper<DocumentT>?) {
        if let write = writeOrNil {
            self.bulkWriteModels.append(write)
        }
    }

    func merge(_ containerOrNil: WriteModelContainer<CollectionT, DocumentT>?) {
        if let container = containerOrNil {
            self.bulkWriteModels.append(contentsOf: container.bulkWriteModels)
        }
    }

    func commitAndClear() -> Bool {
        let success = self.commit()
        self.bulkWriteModels.removeAll()
        return success
    }

    func commit() -> Bool {
        // no-op
        return true
    }
}

/*
 * Write model container that permits committing queued write operations to an instance of WriteModelContainer.
 */
final class MongoCollectionWriteModelContainer<DocumentT: Codable>:
    WriteModelContainer<ThreadSafeMongoCollection<DocumentT>, DocumentT> {
    public override init(_ collection: ThreadSafeMongoCollection<DocumentT>, _ dataSynchronizerLogTag: String) {
        super.init(collection, dataSynchronizerLogTag)
    }

    override func commit() -> Bool {
        if bulkWriteModels.count > 0 {
            if let result = try? collection.bulkWrite(bulkWriteModels.map({$0.writeModel})) {
                return result.matchedCount == result.modifiedCount
            }
            return false
        }
        return true
    }
}

/*
 * Write model container that permits committing queued write operations to an instance of RemoteMongoCollection. Uses
 * type alias for tuple of filter and update values instead of WriteModel because WriteModel in Swift does not expose
 * filter and update. This is a requirement until Stitch server exposes bulk operations.
 */
final class RemoteCollectionWriteModelContainer<DocumentT: Codable>:
    WriteModelContainer<CoreRemoteMongoCollection<DocumentT>, DocumentT> {
    public override init(_ collection: CoreRemoteMongoCollection<DocumentT>, _ dataSynchronizerLogTag: String) {
        super.init(collection, dataSynchronizerLogTag)
    }

    override func commit() -> Bool {
        var success = true
        for writeModel in bulkWriteModels {
            switch writeModel {
            case let .updateOne(filter, update):
                let result = try? collection.updateOne(filter: filter, update: update)
                success = success && result != nil && result?.matchedCount == result?.modifiedCount
            case let .updateMany(filter, update):
                let result = try? collection.updateMany(filter: filter, update: update)
                success = success && result != nil && result?.matchedCount == result?.modifiedCount
            default:
                // ignore
                continue
            }
        }
        return success
    }
}

enum WriteModelWrapper<DocumentT: Codable> {
    case updateOne(filter: Document, update: Document)
    case updateMany(filter: Document, update: Document)
    case writeModel(writeModel: WriteModel)

    var filter: Document {
        switch self {
        case let .updateOne(filter, _):
            return filter
        case let .updateMany(filter, _):
            return filter
        case .writeModel:
            // should be unused
            return [:] as Document
        }
    }

    var update: Codable {
        switch self {
        case let .updateOne(_, update):
            return update
        case let .updateMany(_, update):
            return update
        case .writeModel:
            // should be unused
            return [:] as Document
        }
    }

    var writeModel: WriteModel {
        switch self {
        case let .updateOne(filter, update):
            return MongoCollection<DocumentT>.UpdateOneModel(filter: filter, update: update)
        case let .updateMany(filter, update):
            return MongoCollection<DocumentT>.UpdateManyModel(filter: filter, update: update)
        case let .writeModel(writeModel):
            return writeModel
        }
    }
}

final class LocalSyncWriteModelContainer {
    private let nsConfig: NamespaceSynchronization
    private let localCollection: ThreadSafeMongoCollection<Document>
    private let undoCollection: ThreadSafeMongoCollection<Document>
    private let eventDispatcher: EventDispatcher

    private var localWrites: MongoCollectionWriteModelContainer<Document>
    private var configWrites: MongoCollectionWriteModelContainer<CoreDocumentSynchronization>
    private var remoteWrites: RemoteCollectionWriteModelContainer<Document>
    private var localChangeEvents = [ChangeEvent<Document>]()

    private var ids = Set<AnyBSONValue>()
    private var postCommit: () -> Void = {}

    public init(nsConfig: NamespaceSynchronization, localCollection: ThreadSafeMongoCollection<Document>,
                remoteCollection: CoreRemoteMongoCollection<Document>,
                undoCollection: ThreadSafeMongoCollection<Document>,
                eventDispatcher: EventDispatcher, dataSynchronizerLogTag: String) {
        self.nsConfig = nsConfig
        self.localCollection = localCollection
        self.undoCollection = undoCollection

        self.localWrites = MongoCollectionWriteModelContainer<Document>(localCollection, dataSynchronizerLogTag)
        self.configWrites = MongoCollectionWriteModelContainer<CoreDocumentSynchronization>(nsConfig.docsColl,
                                                                                            dataSynchronizerLogTag)
        self.remoteWrites = RemoteCollectionWriteModelContainer(remoteCollection, dataSynchronizerLogTag)

        self.eventDispatcher = eventDispatcher
    }

    func addDocId(id: AnyBSONValue) {
        ids.insert(id)
    }

    func addLocalWrite(write: WriteModel) {
        localWrites.add(.writeModel(writeModel: write))
    }

    func addRemoteWrite(write: WriteModelWrapper<Document>) {
        remoteWrites.add(write)
    }

    func addConfigWrite(write: WriteModel) {
        configWrites.add(.writeModel(writeModel: write))
    }

    func addLocalChangeEvent(localChangeEvent: ChangeEvent<Document>) {
        localChangeEvents.append(localChangeEvent)
    }

    func merge(_ containerOrNil: LocalSyncWriteModelContainer?) {
        if let container = containerOrNil {
            self.localWrites.merge(container.localWrites)
            self.remoteWrites.merge(container.remoteWrites)
            self.configWrites.merge(container.configWrites)

            container.ids.forEach({(id: AnyBSONValue) in self.ids.insert(id)})
            container.localChangeEvents.forEach({(event: ChangeEvent<Document>)
                in self.localChangeEvents.append(event)})
        }
    }

    func withPostCommit(_ postCommitClosure: @escaping () -> Void) -> LocalSyncWriteModelContainer {
        self.postCommit = postCommitClosure
        return self
    }

    private func wrapForRecovery(_ closure: () throws -> Bool) -> Bool {
        let idsAsArray: [BSONValue] = ids.map({$0.value})

        let oldDocsOrNil: [Document]? = try? localCollection.find(
            ["_id": ["$in": idsAsArray] as Document] as Document).map({$0})

        guard let oldDocs = oldDocsOrNil else {
            return false
        }

        if oldDocs.count > 0 {
            do {
                try undoCollection.insertMany(oldDocs)
            } catch {
                return false
            }
        }

        guard let result: Bool = try? closure() else {
            return false
        }

        if result && oldDocs.count > 0 {
            _ = try? undoCollection.deleteMany(["_id": ["$in": idsAsArray] as Document] as Document)
        }

        return result
    }

    func commitAndClear() {
        let shouldEmitEvents: Bool = wrapForRecovery({
            _ = localWrites.commitAndClear()
            _ = configWrites.commitAndClear()
            return remoteWrites.commitAndClear()
        })

        if shouldEmitEvents {
            localChangeEvents.forEach({self.eventDispatcher.emitEvent(nsConfig: nsConfig, event: $0)})
        }
        localChangeEvents.removeAll()
    }
}

extension MongoCollection.ReplaceOneModel where T == Document {
    init(docConfig: CoreDocumentSynchronization) throws {
        guard let docConfigAsDocument = docConfig.asDocument else {
            throw StitchError.serviceError(withMessage: "failed to convert doc config to document",
                                           withServiceErrorCode: .mongoDBError)
        }

        self.init(filter: docConfigFilter(forNamespace: docConfig.namespace,
                                          withDocumentId: docConfig.documentId),
                  replacement: docConfigAsDocument,
                  upsert: true)
    }
}

extension MongoCollection.UpdateOneModel where T == Document {
    init(docConfig: CoreDocumentSynchronization) throws {
        guard let docConfigAsDocument = docConfig.asDocument else {
            throw StitchError.serviceError(withMessage: "failed to convert doc config to document",
                                           withServiceErrorCode: .mongoDBError)
        }
        self.init(filter: docConfigFilter(forNamespace: docConfig.namespace,
                                          withDocumentId: docConfig.documentId),
                  update: docConfigAsDocument,
                  upsert: true)
    }
}
