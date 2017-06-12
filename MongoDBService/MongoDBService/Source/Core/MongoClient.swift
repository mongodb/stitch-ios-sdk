//
//  MongoClient.swift
//  MongoDBService
//
//  Created by Ofer Meroz on 09/02/2017.
//  Copyright © 2017 Mongo. All rights reserved.
//

import Foundation
import StitchCore

public protocol MongoClient {
    
    var stitchClient: StitchClient { get }
    var serviceName: String { get }        
    
    @discardableResult
    func database(named name: String) -> Database
}
