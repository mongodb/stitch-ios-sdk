//
//  MaxKey.swift
//  MongoExtendedJson
//
//  Created by Ofer Meroz on 26/02/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public struct MaxKey {

    public init(){}
}

// MARK: - Equatable

extension MaxKey: Equatable {
    public static func ==(lhs: MaxKey, rhs: MaxKey) -> Bool {
        return true
    }
}
