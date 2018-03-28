//
//  AuthProviderClientSupplier.swift
//  StitchCore-iOS
//
//  Copyright © 2018 mongodb. All rights reserved.
//

import Foundation
import StitchCore

/**
 * A protocol defining methods necessary to provide an authentication provider client.
 * This protocol is not to be inherited except internally within the StitchCore-iOS module.
 */
public protocol AuthProviderClientSupplier {
    associatedtype Client

    /** :nodoc: */
    func client(withRequestClient requestClient: StitchRequestClient,
                withRoutes routes: StitchAuthRoutes,
                withDispatcher dispatcher: OperationDispatcher) -> Client
}
