//
//  DatabaseType.swift
//  MongoDBService
//
//  Created by Ofer Meroz on 09/02/2017.
//  Copyright © 2017 Mongo. All rights reserved.
//

import Foundation

public protocol DatabaseType {
    
    var client: MongoDBClientType { get }
    var name: String { get }
    
    @discardableResult
    func collection(named name: String) -> CollectionType
}
