//
//  DatabaseImpl.swift
//  MongoDBService
//
//  Created by Ofer Meroz on 25/05/2017.
//  Copyright © 2017 Mongo. All rights reserved.
//

import Foundation

public struct DatabaseImpl: Database {
    
    public let client: MongoClient
    public let name: String
    
    internal init(client: MongoClient, name: String) {
        self.client = client
        self.name = name
    }
    
    // MARK: - Collection
    
    @discardableResult
    public func collection(named name: String) -> Collection {
        return CollectionImpl(database: self, name: name)
    }
}
