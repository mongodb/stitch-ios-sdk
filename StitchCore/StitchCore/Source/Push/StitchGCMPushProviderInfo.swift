//
//  StitchGCMPushProviderInfo.swift
//  StitchCore
//
//  Created by Jay Flax on 6/12/17.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

import ExtendedJson

/**
 * Stitch GCMPushProviderInfo contains information needed to create a `StitchGCMPushClient`.
 */
class StitchGCMPushProviderInfo: PushProviderInfo {
    var providerName: PushProviderName
    var serviceName: String
    
    public let senderID: String
    public let fromProperties: Bool
    
    private init(serviceName: String, senderID: String, fromProperties: Bool) {
        self.providerName = PushProviderName.fromTypeName(typename: PushProviderName.GCM.rawValue)!
        self.serviceName = serviceName
        
        self.senderID = senderID
        self.fromProperties = fromProperties
    }
    
    /**
     * - parameter serviceName: The service that will handle push for this provider.
     * - parameter config: The persisted configuration of this provider.
     * - returns: A GCMPushProviderInfo sourced from a persisted config.
     */
    static func fromConfig(serviceName: String, config: Document) -> StitchGCMPushProviderInfo {
        let senderId = config[Fields.SenderID.rawValue]
        return StitchGCMPushProviderInfo(serviceName: serviceName, senderID: senderId as! String, fromProperties: false)
    }
    
    /**
     * - parameter serviceName: The service that will handle push for this provider.
     * - parameter senderId: The GCM Sender ID.
     * - returns: A GCMPushProviderInfo sourced from a Sender ID.
     */
    static func fromSenderId(serviceName: String, senderId: String) -> StitchGCMPushProviderInfo {
        return StitchGCMPushProviderInfo(serviceName: serviceName, senderID: senderId, fromProperties: false);
    }
    
    /**
     * - returns: The provider info as a serializable document.
     */
    func toDocument() -> Document {
        var doc = Document()
        
        doc[PushProviderInfoFields.FieldType.rawValue] = providerName as? ExtendedJsonRepresentable
        doc[PushProviderInfoFields.Config.rawValue] = Document()
        
        var config = doc[PushProviderInfoFields.Config.rawValue] as! Document
        config[Fields.SenderID.rawValue] = self.senderID
        return doc
    }
    
    enum Fields: String {
        case SenderID = "senderId"
    }
}
