import MongoSwift
import StitchCoreSDK
import StitchCoreLocalMongoDBService
import Foundation

// static global lock for all threads
private let lock = ReadWriteLock(label: "local_mdb_lock")

class ThreadSafeMongoClient {
    private let appInfo: StitchAppClientInfo

    init(withAppInfo appInfo: StitchAppClientInfo) throws {
        self.appInfo = appInfo
    }

    func db(_ name: String) -> ThreadSafeMongoDatabase {
        return ThreadSafeMongoDatabase(appInfo, name: name)
    }

    func close() throws {
        try CoreLocalMongoDBService
            .shared
            .client(withAppInfo: appInfo)
            .close()
    }
}

class ThreadSafeMongoDatabase {
    private let appInfo: StitchAppClientInfo
    private let name: String

    fileprivate init(_ appInfo: StitchAppClientInfo, name: String) {
        self.appInfo = appInfo
        self.name = name
    }

    func collection(_ name: String) -> ThreadSafeMongoCollection<Document> {
        return ThreadSafeMongoCollection<Document>.init(appInfo, databaseName: self.name, name: name)
    }

    func collection<T>(_ name: String, withType type: T.Type) -> ThreadSafeMongoCollection<T> {
        return ThreadSafeMongoCollection(appInfo, databaseName: self.name, name: name)
    }

    func drop() throws {
        try CoreLocalMongoDBService.shared.client(withAppInfo: appInfo).db(name).drop()
    }
}

class ThreadSafeMongoCollection<T: Codable>: Codable {
    enum CodingKeys: CodingKey {
        case databaseKey, dataDirectory, databaseName, name
    }

    private let databaseKey: String
    private let dataDirectory: URL
    private let databaseName: String
    private let name: String

    fileprivate init(_ appInfo: StitchAppClientInfo, databaseName: String, name: String) {
        self.databaseKey = appInfo.clientAppID + "/\(appInfo.authMonitor.activeUserId ?? "unbound")"
        self.dataDirectory = appInfo.dataDirectory
        self.databaseName = databaseName
        self.name = name
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(databaseKey, forKey: .databaseKey)
        try container.encode(dataDirectory, forKey: .dataDirectory)
        try container.encode(name, forKey: .name)
        try container.encode(databaseName, forKey: .databaseName)
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.databaseKey = try container.decode(String.self, forKey: .databaseKey)
        self.databaseName = try container.decode(String.self, forKey: .databaseName)
        self.name = try container.decode(String.self, forKey: .name)
        self.dataDirectory = try container.decode(URL.self, forKey: .dataDirectory)
    }

    fileprivate func underlyingCollection() throws -> MongoCollection<T> {
        return try CoreLocalMongoDBService
            .shared
            .client(withInstanceKey: databaseKey, withDataDirectory: dataDirectory)
            .db(databaseName)
            .collection(name, withType: T.self)
    }

    func drop() throws {
        return try lock.write {
            try underlyingCollection().drop()
        }
    }

    func aggregate(_ pipeline: [Document], options: AggregateOptions? = nil) throws -> MongoCursor<Document> {
        return try lock.write {
            return try underlyingCollection().aggregate(pipeline, options: options)
        }
    }

    func count(_ filter: Document = Document(), options: CountOptions? = nil) throws -> Int {
        return try lock.write {
            return try underlyingCollection().count(filter, options: options)
        }
    }

    func distinct(fieldName: String, filter: Document, options: DistinctOptions? = nil) throws -> [BSONValue?] {
        return try lock.write {
            return try underlyingCollection().distinct(fieldName: fieldName, filter: filter, options: options)
        }
    }

    func find() throws -> MongoCursor<T> {
        return try lock.write {
            return try underlyingCollection().find()
        }
    }

    func find(_ filter: Document, options: FindOptions? = nil) throws -> MongoCursor<T> {
        return try lock.write {
            return try underlyingCollection().find(filter, options: options)
        }
    }

    func findOne(_ filter: Document, options: FindOptions? = nil) throws -> T? {
        return try lock.write {
            let opts: FindOptions!
            if let options = options {
                opts = FindOptions.init(
                    allowPartialResults: options.allowPartialResults,
                    batchSize: options.batchSize,
                    collation: options.collation,
                    comment: options.comment,
                    cursorType: options.cursorType,
                    hint: options.hint,
                    limit: 1,
                    max: options.max,
                    maxAwaitTimeMS: options.maxAwaitTimeMS,
                    maxScan: options.maxScan,
                    maxTimeMS: options.maxTimeMS,
                    min: options.min,
                    noCursorTimeout: options.noCursorTimeout,
                    projection: options.projection,
                    readConcern: options.readConcern,
                    readPreference: options.readPreference,
                    returnKey: options.returnKey,
                    showRecordId: options.showRecordId,
                    skip: options.skip,
                    sort: options.sort)
            } else {
                opts = FindOptions.init(limit: 1)
            }
            return try underlyingCollection().find(filter, options: opts).next()
        }
    }

    @discardableResult
    func findOneAndUpdate(filter: Document, update: Document, options: FindOneAndUpdateOptions? = nil) throws -> T? {
        return try lock.write {
            return try underlyingCollection().findOneAndUpdate(filter: filter, update: update, options: options)
        }
    }

    @discardableResult
    func findOneAndReplace(filter: Document, replacement: T, options: FindOneAndReplaceOptions? = nil) throws -> T? {
        return try lock.write {
            return try underlyingCollection().findOneAndReplace(
                filter: filter, replacement: replacement, options: options
            )
        }
    }

    @discardableResult
    func insertOne(_ value: T) throws -> InsertOneResult? {
        return try lock.write {
            return try underlyingCollection().insertOne(value)
        }
    }

    @discardableResult
    func insertMany(_ values: [T]) throws -> InsertManyResult? {
        return try lock.write {
            return try underlyingCollection().insertMany(values)
        }
    }

    @discardableResult
    func replaceOne(filter: Document, replacement: T, options: ReplaceOptions? = nil) throws -> UpdateResult? {
        return try lock.write {
            return try underlyingCollection().replaceOne(filter: filter, replacement: replacement, options: options)
        }
    }

    @discardableResult
    func updateOne(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        return try lock.write {
            return try underlyingCollection().updateOne(filter: filter, update: update, options: options)
        }
    }

    @discardableResult
    func updateMany(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        return try lock.write {
            return try underlyingCollection().updateMany(filter: filter, update: update, options: options)
        }
    }

    @discardableResult
    func deleteOne(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        return try lock.write {
            return try underlyingCollection().deleteOne(filter, options: options)
        }
    }

    @discardableResult
    func deleteMany(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        return try lock.write {
            return try underlyingCollection().deleteMany(filter, options: options)
        }
    }
}

extension ThreadSafeMongoCollection where T == Document {
    @discardableResult
    func insertOne(_ value: inout T) throws -> InsertOneResult? {
        return try lock.write {
            guard let result = try underlyingCollection().insertOne(value) else {
                return nil
            }

            value["_id"] = result.insertedId

            return result
        }
    }

    @discardableResult
    func insertMany(_ values: inout [T]) throws -> InsertManyResult? {
        return try lock.write {
            guard let result = try underlyingCollection().insertMany(values) else {
                return nil
            }

            result.insertedIds.forEach {
                values[$0.key]["_id"] = $0.value
            }

            return result
        }
    }
}
