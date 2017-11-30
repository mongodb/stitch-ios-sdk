//
//  CustomAuthProvider.swift
//  StitchCore
//
//  Created by Jason Flax on 11/30/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import ExtendedJson

// CustomAuthProvider is a special case that does not
// follow previous protocols.
public struct CustomAuthProvider: AuthProvider {
    public var type: String = "custom-token"

    public var payload: Document { return ["token": jwt] }

    public let jwt: String

    public init(jwt: String) {
        self.jwt = jwt
    }
}
