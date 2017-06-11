//
//  AggregationStage.swift
//  MongoBaasODM
//
//  Created by Yanai Rozenberg on 09/05/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import MongoExtendedJson
import MongoCore

public enum AggregationStage {
    case match(query: Criteria?)
    case sort(sortParameters: [SortParameter])
    case limit(value: Int)
    case count(field: String)
    
    internal var asDocument: Document {
        switch self {
            case .match(let query):
                if let criteria = query {
                    return Document(key: "$match", value: criteria.asDocument)
                }
                else {
                    return Document(key: "$match", value: Document())
                }
            
            case .sort(let sortParameters):
                var sortDocument = Document()
                for sortParameter in sortParameters {
                    sortDocument[sortParameter.field] = sortParameter.direction.rawValue
                }
                return  Document(key: "$sort", value: sortDocument)

            case .limit(let value):
                return Document(key: "$limit", value: value)
            
            case .count(let field):
                return Document(key: "$count", value: field)
            
        }
    }
    
}
