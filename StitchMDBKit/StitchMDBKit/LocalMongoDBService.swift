import Foundation
import MongoMobile
import os
import StitchCore
import StitchCore_iOS

/// Commands associated with reporting battery level
/// to MongoMobile
private enum BatteryLevelCommand: String {
    case mongoCommand = "setBatteryLevel"
    case batteryLevelLow = "low"
    case batteryLevelNormal = "normal"
}

/// Current state of the UIDevice battery
private enum BatteryState {
    case low, normal
}

/// Commands associated with reporting memory level
/// to MongoMobile
private enum TrimMemoryCommand: String {
    case mongoCommand = "trimMemory"
    case aggressiveLevel = "aggressive"
}

/// Name of admin database to communicate commands to
private let adminDatabaseName = "admin"

/// Cached mongoClients associated to app ids
private var localInstances = [String: MongoClient]()

/// Local MongoDB Service Provider
private final class MongoDBServiceClientProvider: ServiceClientProvider {
    public typealias ClientType = MongoClient

    /// Current battery level of this device between 0-100
    private var batteryLevel: Float {
        return UIDevice.current.batteryLevel
    }

    private var lastBatteryState: BatteryState

    public init() {
        // initialize mongo mobile
        MongoMobile.initialize()

        // enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        if UIDevice.current.batteryLevel < 30 {
            self.lastBatteryState = .low
        } else {
            self.lastBatteryState = .normal
        }

        // observe when the battery level changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange(_:)),
            name: .UIDeviceBatteryLevelDidChange,
            object: nil
        )
        // observe when memory warnings are received
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning(_:)),
            name: .UIApplicationDidReceiveMemoryWarning,
            object: nil
        )
    }

    deinit {
        // clean up mobile mongo
        MongoMobile.close()
    }

    public func client(forService service: StitchService,
                       withClientInfo clientInfo: StitchAppClientInfo) throws -> MongoClient {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        // if client is cached, return it
        if let client = localInstances[clientInfo.clientAppId] {
            return client
        }

        // else, create a new client
        let settings = MongoClientSettings(dbPath: NSHomeDirectory())
        let client = try MongoMobile.create(settings)

        localInstances[clientInfo.clientAppId] = client
        return client
    }

    /// Observer for UIDeviceBatteryLevelDidChange notification
    @objc private func batteryLevelDidChange(_ notification: Notification) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if self.lastBatteryState == .normal && self.batteryLevel < 30 {
            // Battery level is low. Start reducing activity to conserve energy.
            os_log("Notifying embedded MongoDB of low host battery level")
            self.lastBatteryState = .low
            localInstances.forEach { (key, client) in
                do {
                    let _ = try client.db(adminDatabaseName)
                        .runCommand([
                            BatteryLevelCommand.mongoCommand.rawValue:
                                BatteryLevelCommand.batteryLevelLow.rawValue
                        ])
                } catch let err {
                    os_log(
                        "Could not notify embedded MongoDB of low host battery level: %@",
                        type: .error,
                        err.localizedDescription
                    )
                }
            }
        } else if self.lastBatteryState == .low && self.batteryLevel >= 40 {
            // Battery level is normal.
            os_log("Notifying embedded MongoDB of normal host battery level")
            self.lastBatteryState = .normal
            localInstances.forEach { (key, client) in
                do {
                    let _ = try client.db(adminDatabaseName)
                        .runCommand([
                            BatteryLevelCommand.mongoCommand.rawValue:
                                BatteryLevelCommand.batteryLevelNormal.rawValue
                            ])
                } catch let err {
                    os_log(
                        "Could not notify embedded MongoDB of normal host battery level: %@",
                        type: .error,
                        err.localizedDescription
                    )
                }
            }
        }
    }

    /// Observer for UIApplicationDidReceiveMemoryWarning notification
    @objc private func didReceiveMemoryWarning(_ notification: Notification) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        os_log("Notifying embedded MongoDB of low memory condition on host")
        localInstances.forEach { (key, client) in
            do {
                let _ = try client.db(adminDatabaseName)
                    .runCommand([
                        TrimMemoryCommand.mongoCommand.rawValue:
                            TrimMemoryCommand.aggressiveLevel.rawValue
                        ])
            } catch let err {
                os_log(
                    "Could not notify embedded MongoDB of normal host battery level: %@",
                    type: .error,
                    err.localizedDescription
                )
            }
        }
    }
}

/// MongoDBService singleton
public let MongoDBService = AnyServiceClientProvider<MongoClient>.init(
    provider: MongoDBServiceClientProvider()
)
