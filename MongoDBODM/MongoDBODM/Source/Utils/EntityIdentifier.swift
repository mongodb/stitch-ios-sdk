//
//  EntityIdentifier.swift
//  MongoDBODM
//
//  Created by Miko Halevi on 4/25/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
/**
 A class type identifier - Use it when you register new BaseEntity subclass
 */
public struct EntityIdentifier: Hashable{
    
    private let objectIdentifier: ObjectIdentifier
    
    //MARK: Init
    
    public init(_ x: AnyObject){
        objectIdentifier = ObjectIdentifier(x)
    }

    public init(_ x: Any.Type){
        objectIdentifier = ObjectIdentifier(x)
    }
    
    //MARK: Hashable
    
    public var hashValue: Int{
        get{
            return objectIdentifier.hashValue
        }
    }
    
    //MARK: Equatable
    
    public static func ==(lhs: EntityIdentifier, rhs: EntityIdentifier) -> Bool    {
        return lhs.objectIdentifier == rhs.objectIdentifier
    }
}
