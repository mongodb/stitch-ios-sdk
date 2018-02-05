import Foundation

private let version = 1
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
fileprivate func runMigration(version: Int?, storage: Storage) {
    switch version {
    case .none:
        // return a promise,
        // mapping each of the store's keys to a Promise
        // that fetches the each value for each key,
        // sets the old value to the new "namespaced" key
        // remove the old key value pair,
        // and set the version number
        let migrations = [
            Consts.AuthJwtKey,
            Consts.AuthRefreshTokenKey,
            Consts.AuthKeychainServiceName,
            Consts.IsLoggedInUDKey
        ].map { key in
            let item = storage.storage.value(forKey: key)
            Promise.resolve(storage.storage.getItem(key))
                .then(item => !!item && storage.store.setItem(storage._generateKey(key), item))
                .then(() => storage.store.removeItem(key))
        }
        return Promise.all(migrations)
            .then(() => storage.store.setItem(_VERSION_KEY, _VERSION));
        // in future versions, `case 1:`, `case 2:` and so on
    // could be added to perform similar migrations
    default: break;
    }
}
/// Storage allows us to store arbitrary data via
/// an arbitrary source. The protocol is modeled
/// after \(Foundation.UserDefaults).
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

/// Protocol conformance for Foundation.UserDefaults
extension UserDefaults: Storage {}
