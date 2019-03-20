@_exported import MongoSwift
@_exported import Foundation
@_exported import MongoMobile
import StitchCoreSDK

/// :nodoc:
public final class CoreLocalMongoDBService {
    public static let shared = CoreLocalMongoDBService()
    private var initialized = false

    private let cLock = ReadWriteLock(label: "clmdbs")
    private var _localInstances = LRUCache<String, MongoClient>(capacity: 10)
    public var localInstances: [MongoClient] {
        return _localInstances.map { $0.1 }
    }
    /// This exists as a mechanism to clear clients
    /// if the dbPath changes, due to the multiple
    /// handles issue.
    private var activeDbPath = ""

    private init() {}

    deinit {
        self.close()
    }

    public func initialize() throws {
        if !initialized {
            try MongoMobile.initialize()
            initialized = true
        }
    }

    public func deleteDatabase(withKey key: String,
                               withDBPath dbPath: String) throws {
        try cLock.write {
            let key = "\(Thread.current.hash)_\(key)"
            var client = _localInstances[key]
            if client == nil {
                client = try self.client(withKey: key, withDBPath: dbPath)
            }

            try client?.listDatabases().forEach {
                guard let name = $0["name"] as? String, name != "admin" else {
                    return
                }

                try client?.db(name).drop()
            }

            var isDir: ObjCBool = true
            let fileManager = FileManager()
            if fileManager.fileExists(atPath: dbPath, isDirectory: &isDir) {
                try fileManager.removeItem(atPath: dbPath)
            }

            client?.close()
            _localInstances[key] = nil
        }
    }

    private func client(withKey key: String,
                        withDBPath dbPath: String) throws -> MongoClient {
        cLock.assertWriteLocked()
        let key = "\(Thread.current.hash)_\(key)"
        if let client = _localInstances[key] {
            return client
        }

        if activeDbPath != dbPath {
            _localInstances.removeAll()
        }

        activeDbPath = dbPath

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

    public func client(withInstanceKey instanceKey: String,
                       withDataDirectory dataDirectory: URL) throws -> MongoClient {
        return try cLock.write {
            let dbPath = "\(dataDirectory.path)/local_mongodb/0/\(instanceKey)"
            return try self.client(withKey: instanceKey, withDBPath: dbPath)
        }
    }

    public func client(withAppInfo appInfo: StitchAppClientInfo) throws -> MongoClient {
        return try self.client(withInstanceKey: appInfo.clientAppID +
            "/\(appInfo.authMonitor.activeUserId ?? "unbound")",
            withDataDirectory: appInfo.dataDirectory)
    }

    public func close() {
        initialized = false
        _localInstances.removeAll()
        try? MongoMobile.close()
    }
}
