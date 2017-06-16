//
//  MongoDBClient.swift
//  MongoDBService
//
//  Created by Ofer Meroz on 25/05/2017.
//  Copyright © 2017 Mongo. All rights reserved.
//

import Foundation
import StitchCore

public class MongoDBClient: MongoDBClientType {
    
    public let stitchClient: StitchClientType
    public let serviceName: String
    
    // MARK: - Init
    
    public required init(stitchClient: StitchClientType, serviceName: String) {
        self.stitchClient = stitchClient
        self.serviceName = serviceName
    }
    
    // MARK: - Public
    
    @discardableResult
    public func database(named name: String) -> DatabaseType {
        return Database(client: self, name: name)
    }
}
