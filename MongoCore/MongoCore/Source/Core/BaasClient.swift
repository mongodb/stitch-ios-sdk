//
//  BaasClient.swift
//  MongoCore
//
//  Created by Ofer Meroz on 02/02/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

public protocol BaasClient {
    
    // MARK: - Properties
    
    var auth: Auth? { get }
    var authUser: AuthUser? { get }
    var isAuthenticated: Bool { get }
    var isAnonymous: Bool { get }
    
    // MARK: - Auth
    
    @discardableResult
    func fetchAuthProviders() -> BaasTask<AuthProviderInfo>
    
    @discardableResult
    func register(email: String, password: String) -> BaasTask<Void>
    
    @discardableResult
    func emailConfirm(token: String, tokenId: String) -> BaasTask<Any>
    
    @discardableResult
    func sendEmailConfirm(toEmail email: String) -> BaasTask<Void>
    
    @discardableResult
    func resetPassword(token: String, tokenId: String) -> BaasTask<Any>
    
    @discardableResult
    func sendResetPassword(toEmail email: String) -> BaasTask<Void>
    
    @discardableResult
    func anonymousAuth() -> BaasTask<Bool>
    
    @discardableResult
    func login(withProvider provider: AuthProvider, link: Bool) -> BaasTask<Bool>
    
    @discardableResult
    func logout() -> BaasTask<Provider?>
    
    // MARK: - Requests    
    
    @discardableResult
    func executePipeline(pipeline: Pipeline) -> BaasTask<Any>
    
    @discardableResult
    func executePipeline(pipelines: [Pipeline]) -> BaasTask<Any>
}

// MARK: - Defaul Values

public extension BaasClient {
    
    @discardableResult
    func login(withProvider provider: AuthProvider, link: Bool = false) -> BaasTask<Bool> {
        return login(withProvider: provider, link: link)
    }
}
