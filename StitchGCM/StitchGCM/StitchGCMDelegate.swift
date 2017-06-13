//
//  APNSListenerService.swift
//  MongoCore
//
//  Created by Jay Flax on 6/6/17.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation
import UserNotifications
import StitchCore

@objc public protocol StitchGCMDelegate {
    func didFailToRegister(error: Error)
    func didReceiveToken(registrationToken: String)
    func didReceiveRemoteNotification(application: UIApplication, pushMessage: PushMessage, handler: ((UIBackgroundFetchResult) -> Void)?)
}
