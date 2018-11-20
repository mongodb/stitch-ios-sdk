@_exported import MongoSwift
@_exported import Foundation
@_exported import MongoMobile
import StitchCoreSDK

private var initialized = false;

open class CoreLocalMongoDBService {
    private static var _localInstances: Dictionary<String, MongoClient> = [String: MongoClient]()

    public static func client(withKey key: String,
                              withDBPath dbPath: String) throws -> MongoClient {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if (!initialized) {
            try MongoMobile.initialize()
            initialized = true
        }

        var isDir : ObjCBool = true
        if !FileManager().fileExists(atPath: dbPath, isDirectory: &isDir) {
            try FileManager().createDirectory(atPath: dbPath, withIntermediateDirectories: true)
        }

        let settings = MongoClientSettings(dbPath: dbPath)
        let client = try MongoMobile.create(settings)

        CoreLocalMongoDBService._localInstances[key] = client
        return client
    }

    public static func client(withAppInfo appInfo: StitchAppClientInfo) throws -> MongoClient {
        if let client = _localInstances[appInfo.clientAppID] {
            return client
        }

        let instanceKey = appInfo.clientAppID
        let dbPath = "\(FileManager().currentDirectoryPath)\(appInfo.dataDirectory.path)/local_mongodb/0/"

        return try client(withKey: instanceKey, withDBPath: dbPath)
    }
    
    public static var localInstances: [MongoClient] {
        // should sync
        return CoreLocalMongoDBService._localInstances.map { $0.value }
    }
    
    public init() {}
    
    deinit {
        self.close()
    }
    
    public func close() {
        initialized = false
        try? MongoMobile.close()
    }
}
