@_exported import MongoSwift
@_exported import Foundation
@_exported import MongoMobile
import StitchCoreSDK

private var initialized = false;

/// :nodoc:
open class CoreLocalMongoDBService {
    private static var _localInstances: Dictionary<String, MongoClient> = [String: MongoClient]()

    public static func client(withAppInfo appInfo: StitchAppClientInfo) throws -> MongoClient {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        if (!initialized) {
            try MongoMobile.initialize()
            initialized = true
        }
    
        if let client = _localInstances[appInfo.clientAppID] {
            return client
        }
        
        let path = "\(FileManager().currentDirectoryPath)\(appInfo.dataDirectory.path)/local_mongodb/0/"
        var isDir : ObjCBool = true
        if !FileManager().fileExists(atPath: path, isDirectory: &isDir) {
            try FileManager().createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        
        let settings = MongoClientSettings(
            dbPath: path
        )
        let client = try MongoMobile.create(settings)
        
        CoreLocalMongoDBService._localInstances[appInfo.clientAppID] = client
        return client
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
