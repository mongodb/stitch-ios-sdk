import Foundation
import StitchCoreSDK
import StitchCoreLocalMongoDBService
import os
import StitchCore
#if canImport(WatchKit)
import WatchKit
#endif
/// Commands associated with reporting battery level
/// to MongoMobile
private enum BatteryLevelCommand: String {
    case mongoCommand = "setBatteryLevel"
    case batteryLevelLow = "low"
    case batteryLevelNormal = "normal"
}

/// Current state of the UIDevice battery
private enum BatteryState {
    case unknown, low, normal
}

/// Commands associated with reporting memory level
/// to MongoMobile
private enum TrimMemoryCommand: String {
    case mongoCommand = "trimMemory"
    case aggressiveLevel = "aggressive"
}

/// Name of admin database to communicate commands to
private let adminDatabaseName = "admin"

/// Local MongoDB Service Provider
private final class MobileMongoDBClientFactory: CoreLocalMongoDBService, ThrowingServiceClientFactory {
    typealias ClientType = MongoClient
    
    /// Current battery level of this device between 0-100
    private var batteryLevel: Float {
        #if os(watchOS)
        return WKInterfaceDevice.current().batteryLevel
        #elseif os(tvOS)
        return 100
        #else
        return UIDevice.current.batteryLevel
        #endif
    }
    
    private var lastBatteryState: BatteryState = .unknown
    
    fileprivate override init() {
        super.init()
        
        #if os(iOS)
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
        // observe when application will terminate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: .UIApplicationWillTerminate,
            object: nil
        )
        #endif
    }
    
    func client(withServiceClient serviceClient: StitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) throws -> MongoClient {
        return try CoreLocalMongoDBService.client(withAppInfo: clientInfo)
    }
    
    /// Private log func due to API level
    private func log(_ msg: StaticString, type: OSLogType = __OS_LOG_TYPE_DEFAULT, _ args: CVarArg...) {
        if #available(iOS 10.0, *) {
            os_log(msg, type: type, args)
        } else {
            // Fallback on earlier versions
            print(String.init(format: msg.description, args))
        }
    }
    
    @objc private func applicationWillTerminate(_ notification: Notification) {
        // close all mongo instances/clients/colls
        self.close()
    }
    
    /// Observer for UIDeviceBatteryLevelDidChange notification
    @objc private func batteryLevelDidChange(_ notification: Notification) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        if self.lastBatteryState == .normal && self.batteryLevel < 30 {
            // Battery level is low. Start reducing activity to conserve energy.
            if #available(iOS 10.0, *) {
                os_log("Notifying embedded MongoDB of low host battery level")
            } else {
                // Fallback on earlier versions
            }
            self.lastBatteryState = .low
            CoreLocalMongoDBService.localInstances.forEach { (client) in
                do {
                    let _ = try client.db(adminDatabaseName)
                        .runCommand([
                            BatteryLevelCommand.mongoCommand.rawValue:
                                BatteryLevelCommand.batteryLevelLow.rawValue
                            ])
                } catch let err {
                    log(
                        "Could not notify embedded MongoDB of low host battery level: %@",
                        type: __OS_LOG_TYPE_ERROR,
                        err.localizedDescription
                    )
                }
            }
        } else if self.lastBatteryState == .low && self.batteryLevel >= 40 {
            // Battery level is normal.
            log("Notifying embedded MongoDB of normal host battery level")
            self.lastBatteryState = .normal
            CoreLocalMongoDBService.localInstances.forEach { (client) in
                do {
                    let _ = try client.db(adminDatabaseName)
                        .runCommand([
                            BatteryLevelCommand.mongoCommand.rawValue:
                                BatteryLevelCommand.batteryLevelNormal.rawValue
                            ])
                } catch let err {
                    log(
                        "Could not notify embedded MongoDB of normal host battery level: %@",
                        type: __OS_LOG_TYPE_ERROR,
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
        
        log("Notifying embedded MongoDB of low memory condition on host")
        CoreLocalMongoDBService.localInstances.forEach { (client) in
            do {
                let _ = try client.db(adminDatabaseName)
                    .runCommand([
                        TrimMemoryCommand.mongoCommand.rawValue:
                            TrimMemoryCommand.aggressiveLevel.rawValue
                        ])
            } catch let err {
                log(
                    "Could not notify embedded MongoDB of normal host battery level: %@",
                    type: __OS_LOG_TYPE_ERROR,
                    err.localizedDescription
                )
            }
        }
    }
}

/// MongoDBService singleton
public let mongoClientFactory = AnyThrowingServiceClientFactory<MongoClient>.init(
    factory: MobileMongoDBClientFactory()
)
