//
//  Sort.swift
//  MongoBaasODM
//
//  Created by Yanai Rozenberg on 22/05/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public struct SortParameter {
    let field: String
    let direction: SortDirection
    
    public init(field: String, direction: SortDirection) {
        self.field = field
        self.direction = direction
    }
}

public enum SortDirection: Int {
    case ascending = 1
    case descending = -1
    
}
