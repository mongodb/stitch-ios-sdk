//
//  Database.swift
//  MongoDB
//
//  Created by Ofer Meroz on 09/02/2017.
//  Copyright © 2017 Mongo. All rights reserved.
//

import Foundation

public protocol Database {
    
    var client: MongoClient { get }
    var name: String { get }
    
    @discardableResult
    func collection(named name: String) -> Collection
}
