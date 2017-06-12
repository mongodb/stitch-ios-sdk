//
//  ProjectionParameter.swift
//  MongoBaasODM
//
//  Created by Miko Halevi on 6/11/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation


public struct ProjectionParameter {
    let field: String
    let expression: ProjectionExpressionRepresentable
    
    public init(field: String, expression: ProjectionExpressionRepresentable) {
        self.field = field
        self.expression = expression
    }
}

