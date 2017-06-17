//
//  Database.swift
//  MongoDBService
//
//  Created by Ofer Meroz on 25/05/2017.
//  Copyright © 2017 Mongo. All rights reserved.
//

import Foundation

public struct Database: DatabaseType {
    
    public let client: MongoDBClientType
    public let name: String
    
    internal init(client: MongoDBClientType, name: String) {
        self.client = client
        self.name = name
    }
    
    // MARK: - Collection
    
    @discardableResult
    public func collection(named name: String) -> CollectionType {
        return Collection(database: self, name: name)
    }
}
