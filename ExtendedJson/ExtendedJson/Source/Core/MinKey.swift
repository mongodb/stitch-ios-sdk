//
//  MinKey.swift
//  ExtendedJson
//
//  Created by Ofer Meroz on 26/02/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public struct MinKey {

    public init(){}
}

// MARK: - Equatable

extension MinKey: Equatable {
    public static func ==(lhs: MinKey, rhs: MinKey) -> Bool {
        return true
    }
}
