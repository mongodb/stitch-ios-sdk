//
//  EntityTypeMetaData.swift
//  MongoBaasODM
//
//  Created by Miko Halevi on 3/19/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import MongoExtendedJson

public protocol EntityTypeMetaData {
     func create(document: Document) -> EmbeddedMongoEntity? //for embedded entities
     func getSchema() -> [String : EntityIdentifier]
     func getEntityIdentifier() -> EntityIdentifier
    
    var collectionName: String {get}
    var databaseName: String {get}

}
