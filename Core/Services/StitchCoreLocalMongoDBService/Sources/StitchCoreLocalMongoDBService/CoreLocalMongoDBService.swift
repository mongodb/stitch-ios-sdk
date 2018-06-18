@_exported import MongoSwift
@_exported import Foundation
import StitchCoreSDK

private var _localInstances = [String: MongoClient]()
private var initialized = false;

open class CoreLocalMongoDBService {
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
        
        _localInstances[appInfo.clientAppID] = client
        return client
    }
    
    public static var localInstances: Dictionary<String, MongoClient>.Values {
        // should sync
        return _localInstances.values
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
