//
//  PushProviderName.swift
//  MongoCore
//
//  Created by Jay Flax on 6/5/17.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

public enum PushProviderName: String {
    case GCM = "gcm"
    
    static let typeNameToProvider: [String: PushProviderName] = [
        PushProviderName.GCM.rawValue: PushProviderName.GCM
    ]
    
    public static func fromTypeName(typename: String) -> PushProviderName? {
        return typeNameToProvider[typename]
    }
}
