import Foundation

private let latestVersion = 1
private let versionKey = "__stitch_storage_version__"

/**
 * Run a migration on the currently used storage
 * that checks to see if the current version is up to date.
 * If the version has not been set, this method will migrate
 * to the latest version.
 * @param {Integer} version version number of storage
 * @param {Object} storage storage class being checked
 * @returns {Promise} nullable promise containing migration logic
 */
internal func runMigration(suiteName: String, storage: Storage) {
    switch storage.value(forKey: versionKey) {
    case .none:
    #if !os(Linux)
        // map each of the store's keys to a Promise
        // that fetches the each value for each key,
        // sets the old value to the new "namespaced" key
        // remove the old key value pair,
        // and set the version number
        // we only care about UserDefaults here since no other
        // `Storage` type was available before version 1
        guard var originalStorage = UserDefaults.init(suiteName: "com.mongodb.stitch.sdk.UserDefaults"),
            var newStorage = UserDefaults.init(suiteName: "com.mongodb.stitch.sdk.UserDefaults.\(suiteName)") else {
                return
        }

        // legacy keys
        ["StitchCoreAuthJwtKey",
         "StitchCoreAuthRefreshTokenKey",
         "com.mongodb.stitch.sdk.authentication",
         "StitchCoreIsLoggedInUserDefaultsKey"].forEach { key in
            newStorage[key] = originalStorage[key]
            originalStorage[key] = nil
        }
        newStorage[versionKey] = latestVersion
    #endif
    // in future versions, `case 1:`, `case 2:` and so on
    // could be added to perform similar migrations
    default: break
    }
}

internal struct StorageKeys {
    internal let isLoggedInUDKey: String
    internal let authJwtKey: String
    internal let authRefreshTokenKey: String
    internal let authKeychainServiceName: String

    init(suiteName: String) {
        self.isLoggedInUDKey = "StitchCoreIsLoggedInUserDefaultsKey.\(suiteName)"
        self.authJwtKey = "StitchCoreAuthJwtKey.\(suiteName)"
        self.authRefreshTokenKey = "StitchCoreAuthRefreshTokenKey.\(suiteName)"
        self.authKeychainServiceName = "com.mongodb.stitch.sdk.authentication.\(suiteName)"
    }
}

/// Storage allows us to store arbitrary data via
/// an arbitrary source. The protocol is modeled
/// after Foundation.UserDefaults.
public protocol Storage {
    /// Initialize new Storage unit
    /// - parameter suiteName: namespace for this storage suite
    /// - returns: a new Storage unit, or nil if the suiteName is invalid
    init?(suiteName: String?)

    /// Read value for key
    /// - parameter forKey key: key to read from
    /// - returns: value for key
    func value(forKey key: String) -> Any?

    /// Set value for key
    /// - parameter value: value to save
    /// - parameter forKey key: key to save value for
    mutating func set(_ value: Any?, forKey key: String)

    /// Remove object for key
    /// - parameter forKey key: key to remove value for
    mutating func removeObject(forKey key: String)
}

extension Storage {
    subscript(key: String) -> Any? {
        get {
            return self.value(forKey: key)
        }
        set {
            if let value = newValue {
                self.set(value, forKey: key)
            } else {
                self.removeObject(forKey: key)
            }
        }
    }
}

/// Failover implementation of the Storage protocol
/// in the event that no other storage unit can
/// be found.
internal struct MemoryStorage: Storage {
    /// Namespace of this suite
    private let suiteName: String
    /// Internal storage unit
    fileprivate var storage: [String: Any] = [:]

    init?(suiteName: String?) {
        guard let suiteName = suiteName else {
            return nil
        }

        self.suiteName = suiteName
    }

    fileprivate func generateKey(forKey key: String) -> String {
        return "\(suiteName).\(key)"
    }

    func value(forKey key: String) -> Any? {
        return self.storage[generateKey(forKey: key)]
    }

    mutating func set(_ value: Any?, forKey key: String) {
        self.storage[generateKey(forKey: key)] = value
    }

    mutating func removeObject(forKey key: String) {
        self.storage.removeValue(forKey: generateKey(forKey: key))
    }
}

#if !os(Linux)
/// Protocol conformance for Foundation.UserDefaults
extension UserDefaults: Storage {}
#endif
