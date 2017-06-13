//
//  PushClient.swift
//  MongoCore
//
//  Created by Jay Flax on 6/5/17.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation
import ExtendedJson

let PrefConfigs: String = "apns.configs"

public enum DeviceFields: String {
    case ServiceName = "service"
    case Data = "data"
    case RegistrationToken = "registrationToken"
}

public enum Actions: String {
    case RegisterPush = "registerPush"
    case DeregisterPush = "deregisterPush"
}

/**
    A PushClient is responsible for allowing users to register and deregister for push notifications sent from Stitch or directly from the provider.
 */
public protocol PushClient {
    var stitchClient: StitchClient { get }
    var userDefaults: UserDefaults { get }
    
    /**
        Registers the client with the provider and Stitch
 
        - returns: A task that can be resolved upon registering
    */
    @discardableResult
    func registerToken(token: String) -> StitchTask<Void>
    
    /**
        Deregisters the client from the provider and Stitch.
        
        - returns: A task that can be resolved upon deregistering
    */
    @discardableResult
    func deregister() -> StitchTask<Void>
}

extension PushClient {
    /**
     - parameter info: The push provider info to persist.
     */
    func addInfoToConfigs(info: PushProviderInfo) {
        var configs = Document()
        do {
            configs = try Document(extendedJson: userDefaults.value(forKey: PrefConfigs) as! [String : Any])
        } catch _ {
            configs = Document()
        }
        
        configs[info.serviceName] = info.toDocument().toExtendedJson as? ExtendedJsonRepresentable
        userDefaults.setValue(configs, forKey: PrefConfigs)
    }
    
    /**
     - parameter info: The push provider info to no longer persist
     */
    public func removeInfoFromConfigs(info: PushProviderInfo) {
        var configs = Document()
        do {
            configs = try Document(extendedJson: userDefaults.value(forKey: PrefConfigs) as! [String : Any])
        } catch _ {
            configs = Document()
        }
        
        configs[info.serviceName] = nil
        userDefaults.setValue(configs, forKey: PrefConfigs)
    }
    
    /**
     - parameter serviceName: The service that will handle push
     for this client
     - returns: A generic device registration request
     */
    public func getBaseRegisterPushRequest(serviceName: String) -> Document {
        var request = Document()
        
        request[DeviceFields.ServiceName.rawValue] = serviceName
        request[DeviceFields.Data.rawValue] = Document()

        return request
    }
    
    /**
     - parameter serviceName: The service that will handle push
     for this client
     - returns: A generic device deregistration request
     */
    func getBaseDeregisterPushDeviceRequest(serviceName: String) -> Document {
        var request = Document()
        
        request[DeviceFields.ServiceName.rawValue] = serviceName
        
        return request
    }
}
