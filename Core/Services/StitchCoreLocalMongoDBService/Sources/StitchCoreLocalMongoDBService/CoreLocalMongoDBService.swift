@_exported import MongoSwift
@_exported import Foundation
@_exported import MongoMobile
import StitchCoreSDK

/// :nodoc:
public final class CoreLocalMongoDBService {
    public static let shared = CoreLocalMongoDBService()
    private var initialized = false

    private var _localInstances = LRUCache<String, MongoClient>(capacity: 10)
    public var localInstances: [MongoClient] {
        return _localInstances.map { $0.1 }
    }

/// :nodoc:
open class CoreLocalMongoDBService {
    private static var _localInstances: Dictionary<String, MongoClient> = [String: MongoClient]()

    deinit {
        self.close()
    }

    public func initialize() throws {
        if !initialized {
            try MongoMobile.initialize()
            initialized = true
        }
    }

    public func client(withKey key: String,
                       withDBPath dbPath: String) throws -> MongoClient {
        let key = "\(Thread.current.hash)_\(key)"
        if let client = _localInstances[key] {
            return client
        }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        try initialize()

        var isDir: ObjCBool = true
        let fileManager = FileManager()
        if !fileManager.fileExists(atPath: dbPath, isDirectory: &isDir) {
            try fileManager.createDirectory(atPath: dbPath, withIntermediateDirectories: true)
        }

        let settings = MongoClientSettings(dbPath: dbPath)
        let client = try MongoMobile.create(settings)

        _localInstances[key] = client
        return client
    }

    public func client(withClientAppID clientAppID: String,
                       withDataDirectory dataDirectory: URL) throws -> MongoClient {
        let instanceKey = clientAppID
        let dbPath = "\(FileManager().currentDirectoryPath)\(dataDirectory.path)/local_mongodb/0/"
        return try self.client(withKey: instanceKey, withDBPath: dbPath)
    }

    public func client(withAppInfo appInfo: StitchAppClientInfo) throws -> MongoClient {
        return try self.client(withClientAppID: appInfo.clientAppID, withDataDirectory: appInfo.dataDirectory)
    }

    public func close() {
        initialized = false
        _localInstances.removeAll()
        try? MongoMobile.close()
    }
}
