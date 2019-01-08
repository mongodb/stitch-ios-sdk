import MongoSwift
import StitchCoreSDK
import StitchCoreLocalMongoDBService
import Foundation

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

class ThreadSafeMongoCollection<T: Codable> {
    private let appInfo: StitchAppClientInfo
    private let databaseName: String
    private let name: String

    fileprivate init(_ appInfo: StitchAppClientInfo, databaseName: String, name: String) {
        self.appInfo = appInfo
        self.databaseName = databaseName
        self.name = name
    }

    fileprivate func underlyingCollection() throws -> MongoCollection<T> {
        return try CoreLocalMongoDBService
            .shared
            .client(withAppInfo: appInfo)
            .db(databaseName)
            .collection(name, withType: T.self)
    }

    func drop() throws {
        try underlyingCollection().drop()
    }

    func aggregate(_ pipeline: [Document], options: AggregateOptions? = nil) throws -> MongoCursor<Document> {
        return try underlyingCollection().aggregate(pipeline, options: options)
    }

    func count(_ filter: Document = Document(), options: CountOptions? = nil) throws -> Int {
        return try underlyingCollection().count(filter, options: options)
    }

    func distinct(fieldName: String, filter: Document, options: DistinctOptions? = nil) throws -> [BSONValue?] {
        return try underlyingCollection().distinct(fieldName: fieldName, filter: filter, options: options)
    }

    func find() throws -> MongoCursor<T> {
        return try underlyingCollection().find()
    }

    func find(_ filter: Document, options: FindOptions? = nil) throws -> MongoCursor<T> {
        return try underlyingCollection().find(filter, options: options)
    }

    @discardableResult
    func findOneAndUpdate(filter: Document, update: Document, options: FindOneAndUpdateOptions? = nil) throws -> T? {
        return try underlyingCollection().findOneAndUpdate(filter: filter, update: update, options: options)
    }

    @discardableResult
    func findOneAndReplace(filter: Document, replacement: T, options: FindOneAndReplaceOptions? = nil) throws -> T? {
        return try underlyingCollection().findOneAndReplace(filter: filter, replacement: replacement, options: options)
    }

    @discardableResult
    func insertOne(_ value: T) throws -> InsertOneResult? {
        return try underlyingCollection().insertOne(value)
    }

    @discardableResult
    func insertMany(_ values: [T]) throws -> InsertManyResult? {
        return try underlyingCollection().insertMany(values)
    }

    @discardableResult
    func replaceOne(filter: Document, replacement: T, options: ReplaceOptions? = nil) throws -> UpdateResult? {
        return try underlyingCollection().replaceOne(filter: filter, replacement: replacement, options: options)
    }

    @discardableResult
    func updateOne(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        return try underlyingCollection().updateOne(filter: filter, update: update, options: options)
    }

    @discardableResult
    func updateMany(filter: Document, update: Document, options: UpdateOptions? = nil) throws -> UpdateResult? {
        return try underlyingCollection().updateMany(filter: filter, update: update, options: options)
    }

    @discardableResult
    func deleteOne(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        return try underlyingCollection().deleteOne(filter, options: options)
    }

    @discardableResult
    func deleteMany(_ filter: Document, options: DeleteOptions? = nil) throws -> DeleteResult? {
        return try underlyingCollection().deleteMany(filter, options: options)
    }
}
