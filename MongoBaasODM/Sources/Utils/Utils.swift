//
//  Utils.swift
//  MongoBaasODM
//
//  Created by Miko Halevi on 3/22/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import UIKit

class Utils {
    
    static var entitiesDictionary: [EntityIdentifier : EntityTypeMetaData] = [:]
    
    public static func getIdentifier(any : Any) -> EntityIdentifier{
        return EntityIdentifier(type(of: any))
    }
    
    public static func getIdentifier(type : Any.Type) -> EntityIdentifier{
        return EntityIdentifier(type)
    }
    
    internal struct Consts{
        static let objectIdKey = "_id"
    }
    
}
