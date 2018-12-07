@_exported import MongoSwift
@_exported import Foundation
@_exported import MongoMobile
import StitchCoreSDK

public final class CoreLocalMongoDBService {
    public static let shared = CoreLocalMongoDBService()
    private var handles = 0
    private var initialized = false
    private var _localInstances = [String: MongoClient]()
    public var localInstances: [MongoClient] {
        // should sync
        return _localInstances.map { $0.value }
    }

/// :nodoc:
open class CoreLocalMongoDBService {
    private static var _localInstances: Dictionary<String, MongoClient> = [String: MongoClient]()

    deinit {
        self.close()
    }

    public func initialize() throws {
        if (!initialized) {
            try MongoMobile.initialize()
            initialized = true
        }
    }

    public func client(withKey key: String,
                       withDBPath dbPath: String) throws -> MongoClient {
        if let client = _localInstances[key] {
            return client
        }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        try initialize()

        var isDir : ObjCBool = true
        if !FileManager().fileExists(atPath: dbPath, isDirectory: &isDir) {
            try FileManager().createDirectory(atPath: dbPath, withIntermediateDirectories: true)
        }

        let settings = MongoClientSettings(dbPath: dbPath)
        let client = try MongoMobile.create(settings)

        _localInstances[key] = client
        return client
    }

    public func client(withAppInfo appInfo: StitchAppClientInfo) throws -> MongoClient {
        if let client = _localInstances[appInfo.clientAppID] {
            return client
        }

        let instanceKey = appInfo.clientAppID
        let dbPath = "\(FileManager().currentDirectoryPath)\(appInfo.dataDirectory.path)/local_mongodb/0/"

        return try client(withKey: instanceKey, withDBPath: dbPath)
    }
    
    public func close() {
        initialized = false
        _localInstances.removeAll()
        try? MongoMobile.close()
    }
}
