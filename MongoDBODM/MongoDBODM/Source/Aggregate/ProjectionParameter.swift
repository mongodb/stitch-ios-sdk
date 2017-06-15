//
//  ProjectionParameter.swift
//  MongoDBODM
//
//  Created by Miko Halevi on 6/11/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
/**
 Used as a parameter in AggregationStage.project
 */
public struct ProjectionParameter {
    let field: String
    let expression: ProjectionExpressionRepresentable
    
    public init(field: String, expression: ProjectionExpressionRepresentable) {
        self.field = field
        self.expression = expression
    }
}

