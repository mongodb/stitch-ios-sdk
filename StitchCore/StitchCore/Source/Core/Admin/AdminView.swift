//
//  AdminView.swift
//  StitchCore
//
//  Created by Jason Flax on 2/2/18.
//  Copyright © 2018 MongoDB. All rights reserved.
//

import Foundation

protocol AdminView {
    var request: Encodable { get }
    var response: Decodable { get }
}
