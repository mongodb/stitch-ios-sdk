//
//  AuthListener.swift
//  MongoCore
//
//  Created by Jay Flax on 6/5/17.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

public protocol AuthDelegate {
    /**
        Called when a user is logged in
    */
    func onLogin()
    
    /**
        Called when a user is logged out
 
        - parameter lastProvider: The last provider this user
            logged in with
    */
    func onLogout(lastProvider: String)
}
