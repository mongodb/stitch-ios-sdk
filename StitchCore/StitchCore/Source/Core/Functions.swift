//
//  Functions.swift
//  StitchCore
//
//  Created by Jason Flax on 11/14/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import ExtendedJson

internal struct Function: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name, arguments, service
    }

    let name: String
    let arguments: [ExtendedJsonRepresentable]
    let service: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: CodingKeys.name)

        let argEncoder = container.superEncoder(forKey: CodingKeys.arguments)
        var unkeyedContainer = argEncoder.unkeyedContainer()
        let unkeyedArgEncoder = unkeyedContainer.superEncoder()
        try arguments.forEach {
            try $0.encode(to: unkeyedArgEncoder)
        }
        try container.encodeIfPresent(service, forKey: CodingKeys.service)
    }
}
