//
//  APNSPushClient.swift
//  MongoCore
//
//  Created by Jay Flax on 6/5/17.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation
import UserNotifications
import ExtendedJson

public class StitchGCMPushClient: PushClient {
    enum Props: String {
        case GCMServiceName = "push.gcm.service"
        case GCMSenderID = "push.gcm.senderId"
    }
    
    public let userDefaults: UserDefaults = UserDefaults(suiteName: Consts.UserDefaultsName)!

    public let stitchClient: StitchClient
    
    init(stitchClient: StitchClient, info: StitchGCMPushProviderInfo) {
        self.stitchClient = stitchClient
    }
    
    /**
        -parameter registrationToken: The registration token from GCM.
        -returns: The request payload for registering for push for GCM.
     */
    private func getRegisterPushDeviceRequest(registrationToken: String) -> Document {
    
        let request = getBaseRegisterPushRequest(serviceName: "")
        var data = request[DeviceFields.Data.rawValue] as! Document
        data[DeviceFields.RegistrationToken.rawValue] = registrationToken
    
        return request
    }

    
    public func registerToken(token: String) -> StitchTask<Void> {
        userDefaults.setValue(token, forKey: DeviceFields.RegistrationToken.rawValue)
        let pipeline: Pipeline = Pipeline(action: Actions.RegisterPush.rawValue,
                                         args: getRegisterPushDeviceRequest(registrationToken: token).toExtendedJson as? [String : ExtendedJsonRepresentable])
        
        return stitchClient.executePipeline(pipeline: pipeline).continuationTask { task -> Void in
            
        }
    }
    
    /**
        Deregisters the client from the provider and Stitch.
     
     - returns: A task that can be resolved upon deregistering
     */
    public func deregister() -> StitchTask<Void> {
        let deviceToken = userDefaults.string(forKey: DeviceFields.RegistrationToken.rawValue)
        let pipeline: Pipeline = Pipeline(action: Actions.RegisterPush.rawValue,
                                          args: getRegisterPushDeviceRequest(registrationToken: deviceToken!).toExtendedJson as? [String : ExtendedJsonRepresentable])
        return stitchClient.executePipeline(pipeline: pipeline).continuationTask { task -> Void in
            
        }
    }
}
