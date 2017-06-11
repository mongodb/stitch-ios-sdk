//
//  StitchClient.swift
//  MongoCore
//
//  Created by Ofir Zucker on 07/06/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

public protocol StitchClient {
    
    // MARK: - Properties
    
    var auth: Auth? { get }
    var authUser: AuthUser? { get }
    var isAuthenticated: Bool { get }
    var isAnonymous: Bool { get }
    
    // MARK: - Auth
    
    @discardableResult
    func fetchAuthProviders() -> StitchTask<AuthProviderInfo>
    
    @discardableResult
    func register(email: String, password: String) -> StitchTask<Void>
    
    @discardableResult
    func emailConfirm(token: String, tokenId: String) -> StitchTask<Any>
    
    @discardableResult
    func sendEmailConfirm(toEmail email: String) -> StitchTask<Void>
    
    @discardableResult
    func resetPassword(token: String, tokenId: String) -> StitchTask<Any>
    
    @discardableResult
    func sendResetPassword(toEmail email: String) -> StitchTask<Void>
    
    @discardableResult
    func anonymousAuth() -> StitchTask<Bool>
    
    @discardableResult
    func login(withProvider provider: AuthProvider, link: Bool) -> StitchTask<Bool>
    
    @discardableResult
    func logout() -> StitchTask<Provider?>
    
    // MARK: - Requests
    
    @discardableResult
    func executePipeline(pipeline: Pipeline) -> StitchTask<Any>
    
    @discardableResult
    func executePipeline(pipelines: [Pipeline]) -> StitchTask<Any>
}

// MARK: - Defaul Values

public extension StitchClient {
    
    @discardableResult
    func login(withProvider provider: AuthProvider, link: Bool = false) -> StitchTask<Bool> {
        return login(withProvider: provider, link: link)
    }
}
