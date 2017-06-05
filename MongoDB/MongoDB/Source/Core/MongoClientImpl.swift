//
//  MongoClientImpl.swift
//  MongoDB
//
//  Created by Ofer Meroz on 25/05/2017.
//  Copyright © 2017 Mongo. All rights reserved.
//

import Foundation
import MongoCore

public class MongoClientImpl: MongoClient {        
    
    public let baasClient: BaasClient
    public let serviceName: String
    
    // MARK: - Init
    
    public required init(baasClient: BaasClient, serviceName: String) {
        self.baasClient = baasClient
        self.serviceName = serviceName
    }
    
    // MARK: - Public
    
    @discardableResult
    public func database(named name: String) -> Database {
        return DatabaseImpl(client: self, name: name)
    }
}
