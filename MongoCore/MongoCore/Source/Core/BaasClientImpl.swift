//
//  BaasClientImpl.swift
//  MongoCore
//
//  Created by Ofer Meroz on 19/03/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation
import MongoExtendedJson
import MongoBaasSDKLogger

public class BaasClientImpl: BaasClient {
    
    private struct Consts {
        static let DefaultBaseUrl =         "https://baas-dev.10gen.cc"
        static let ApiPath =                "/api/client/v1.0/app/"
        static let AuthJwtUDKey =           "MongoCoreAuthJwtUserDefaultsKey"
        static let AuthRefreshTokenUDKey =  "MongoCoreAuthRefreshTokenUserDefaultsKey"
        static let UserDefaultsName =       "com.mongodb.baas.sdk.UserDefaults"
        
        //keys
        static let ResultKey =              "result"
        static let AccessTokenKey =         "accessToken"
        static let RefreshTokenKey =        "refreshToken"
        static let ErrorKey =               "error"
        static let ErrorCodeKey =           "errorCode"
        
        //api
        static let AuthPath =               "auth"
        static let NewAccessTokenPath =     "newAccessToken"
        static let PipelinePath =           "pipeline"
    }
    
    // MARK: - Properties
    
    private var appId: String
    private var baseUrl: String
    private let networkAdapter: NetworkAdapter
    
    private let userDefaults = UserDefaults(suiteName: Consts.UserDefaultsName)
    
    public private(set) var auth: Auth? {
        didSet{
            if let newValue = auth {
                // save auth persistently
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: newValue.json, options: JSONSerialization.WritingOptions())
                    let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)
                    userDefaults?.set(jsonString, forKey: Consts.AuthJwtUDKey)
                } catch let error as NSError {
                    printLog(.error, text: "failed saving auth to user defaults, array to JSON conversion failed: \(error.localizedDescription)")
                }
            }
            else {
                // remove from user defaults
                userDefaults?.removeObject(forKey: Consts.AuthJwtUDKey)
            }
        }
    }
    
    public var authUser: AuthUser? {
        return auth?.user
    }
    
    public var isAuthenticated: Bool {
        
        guard auth == nil else {
            return true
        }
        
        do {
            auth = try getAuthFromSavedJwt()
        }
        catch {
            printLog(.error, text: error.localizedDescription)
        }
        
        return auth != nil
    }
    
    public var isAnonymous: Bool {
        return isAuthenticated && auth?.provider == .anonymous
    }
    
    private var refreshToken: String? {
        
        guard isAuthenticated else {
            return nil
        }
        return userDefaults?.object(forKey: Consts.AuthRefreshTokenUDKey) as? String
    }
    
    // MARK: - Init
    
    public init(appId: String, baseUrl: String = Consts.DefaultBaseUrl + Consts.ApiPath, networkAdapter: NetworkAdapter = AlamofireNetworkAdapter()) {
        self.appId = appId
        self.baseUrl = baseUrl
        self.networkAdapter = networkAdapter
    }
    
    // MARK: - Auth
    
    @discardableResult
    public func fetchAuthProviders() -> BaasTask<AuthProviderInfo> {
        let task = BaasTask<AuthProviderInfo>()
        let url = "\(baseUrl)\(appId)/\(Consts.AuthPath)"
        networkAdapter.requestWithJsonEncoding(url: url, method: .get, parameters: nil, headers: nil).response(onQueue: DispatchQueue.global(qos: .utility)) { [weak self] (response) in
            guard let strongSelf = self else {
                task.result = BaasResult.failure(BaasError.clientReleased)
                return
            }
            
            switch response {
            case .success(let value):
                if let value = value as? [String : Any] {
                    if let error = strongSelf.parseError(from: value) {
                        task.result = .failure(error)
                    }
                    else {
                        task.result = .success(AuthProviderInfo(dictionary: value))
                    }
                }
                
            case .failure(let error):
                task.result = .failure(error)
                
            }
        }
       
        return task
    }
    
    @discardableResult
    public func register(email: String, password: String) -> BaasTask<Void> {
        let task = BaasTask<Void>()
        let provider = EmailPasswordAuthProvider(username: email, password: password)
        let url = "\(baseUrl)\(appId)/\(Consts.AuthPath)/\(provider.type)/\(provider.name)/register"
        let payload = ["email" : email, "password" : password]
        networkAdapter.requestWithJsonEncoding(url: url, method: .post, parameters: payload, headers: nil).response { [weak self] (result) in
            
            guard let strongSelf = self else {
                task.result = BaasResult.failure(BaasError.clientReleased)
                return
            }
            
            switch result {
            case .success(let value):
                if let value = value as? [String : Any] {
                    if let error = strongSelf.parseError(from: value) {
                        task.result = .failure(error)
                    }
                    else {
                        task.result = .success()
                    }
                }
            case .failure(let error):
                task.result = .failure(error)
            }
        }
        
        return task
    }
    
    @discardableResult
    public func emailConfirm(token: String, tokenId: String) -> BaasTask<Any> {
        let task = BaasTask<Any>()
        let url = "\(baseUrl)\(appId)/\(Consts.AuthPath)/local/userpass/confirm"
        let params = ["token" : token, "tokenId" : tokenId]
        networkAdapter.requestWithJsonEncoding(url: url, method: .post, parameters: params, headers: nil).response { [weak self] (result) in
            guard let strongSelf = self else {
                task.result = BaasResult.failure(BaasError.clientReleased)
                return
            }
            
            switch result {
            case .success(let value):
                if let value = value as? [String : Any] {
                    if let error = strongSelf.parseError(from: value) {
                        task.result = .failure(error)
                    }
                    else {
                        task.result = .success(value)
                    }
                }
            case .failure(let error):
                task.result = .failure(error)
            }
        }
        
        return task
    }
    
    @discardableResult
    public func sendEmailConfirm(toEmail email: String) -> BaasTask<Void> {
        let task = BaasTask<Void>()
        let url = "\(baseUrl)\(appId)/\(Consts.AuthPath)/local/userpass/confirm/send"
        let params = ["email" : email]
        networkAdapter.requestWithJsonEncoding(url: url, method: .post, parameters: params, headers: nil).response { [weak self] (result) in
            guard let strongSelf = self else {
                task.result = BaasResult.failure(BaasError.clientReleased)
                return
            }
            
            switch result {
            case .success(let value):
                if let value = value as? [String : Any] {
                    if let error = strongSelf.parseError(from: value) {
                        task.result = .failure(error)
                    }
                    else {
                        task.result = .success()
                    }
                }
            case .failure(let error):
                task.result = .failure(error)
            }
        }
        
        return task
    }
    
    @discardableResult
    public func resetPassword(token: String, tokenId: String) -> BaasTask<Any> {
        let task = BaasTask<Any>()
        let url = "\(baseUrl)\(appId)/\(Consts.AuthPath)/local/userpass/reset"
        let params = ["token" : token, "tokenId" : tokenId]
        networkAdapter.requestWithJsonEncoding(url: url, method: .post, parameters: params, headers: nil).response { [weak self] (result) in
            guard let strongSelf = self else {
                task.result = BaasResult.failure(BaasError.clientReleased)
                return
            }
            
            switch result {
            case .success(let value):
                if let value = value as? [String : Any] {
                    if let error = strongSelf.parseError(from: value) {
                        task.result = .failure(error)
                    }
                    else {
                        task.result = .success(value)
                    }
                }
            case .failure(let error):
                task.result = .failure(error)
            }
        }
        
        return task
    }
    
    @discardableResult
    public func sendResetPassword(toEmail email: String) -> BaasTask<Void> {
        let task = BaasTask<Void>()
        let url = "\(baseUrl)\(appId)/\(Consts.AuthPath)/local/userpass/reset/send"
        let params = ["email" : email]
        networkAdapter.requestWithJsonEncoding(url: url, method: .post, parameters: params, headers: nil).response { [weak self] (result) in
            guard let strongSelf = self else {
                task.result = BaasResult.failure(BaasError.clientReleased)
                return
            }
            
            switch result {
            case .success(let value):
                if let value = value as? [String : Any] {
                    if let error = strongSelf.parseError(from: value) {
                        task.result = .failure(error)
                    }
                    else {
                        task.result = .success()
                    }
                }
            case .failure(let error):
                task.result = .failure(error)
            }
        }
        
        return task
    }
    
    @discardableResult
    public func anonymousAuth() -> BaasTask<Bool> {
        return login(withProvider: AnonymousAuthProvider())
    }
    
    @discardableResult
    public func login(withProvider provider: AuthProvider, link: Bool = false) -> BaasTask<Bool> {
        let task = BaasTask<Bool>()
        
        if isAuthenticated && !link {
            printLog(.info, text: "Already logged in, using cached token.")
            task.result = .success(true)
            return task
        }
        
        var url = "\(baseUrl)\(appId)/\(Consts.AuthPath)/\(provider.type)/\(provider.name)"
        if link {
            guard let auth = auth else {
                task.result = .failure(BaasError.illegalAction(message: "In order to link a new authentication provider you must first be authenticated."))
                return task
            }
            
            url += "?link=\(auth.accessToken)"
        }
        
        networkAdapter.requestWithJsonEncoding(url: url, method: .post, parameters: provider.payload, headers: nil).response(onQueue: DispatchQueue.global(qos: .utility)) { [weak self] (response) in
            guard let strongSelf = self else {
                task.result = BaasResult.failure(BaasError.clientReleased)
                return
            }
            
            switch response {
            case .success(let value):
                if let value = value as? [String : Any] {
                    if let error = strongSelf.parseError(from: value) {
                        task.result = .failure(error)
                    }
                    else {
                        do {
                            strongSelf.auth = try Auth(dictionary: value)
                        }
                        catch let error {
                            printLog(.error, text: "failed creating Auth: \(error)")
                            task.result = .failure(error)
                        }
                        
                        if strongSelf.auth != nil {
                            
                            
                            if let refreshToken = value[Consts.RefreshTokenKey] as? String {
                                strongSelf.userDefaults?.set(refreshToken, forKey: Consts.AuthRefreshTokenUDKey)
                            }
                            task.result = .success(true)
                        }
                    }
                }
                else {
                    printLog(.error, text: "Login failed - failed parsing auth response.")
                    task.result = .failure(BaasError.responseParsingFailed(reason: "Invalid auth response - expected json and received: \(value)"))
                }
            case .failure(let error):
                task.result = .failure(error)
                
            }
        }
        
        return task
    }
    
    @discardableResult
    public func logout() -> BaasTask<Provider?> {
        let task = BaasTask<Provider?>()
        
        if !isAuthenticated {
            printLog(.info, text: "Tried logging out while there was no authenticated user found.")
            task.result = .success(nil)
            return task
        }
        
        let provider = auth!.provider
        performRequest(method: .delete, endpoint: Consts.AuthPath, parameters: nil, refreshOnFailure: false, useRefreshToken: true).response(onQueue: DispatchQueue.global(qos: .utility)) { [weak self] (result) in
            guard let strongSelf = self else {
                task.result = BaasResult.failure(BaasError.clientReleased)
                return
            }
            
            if let error = result.error {
                task.result = .failure(error)
            }
            else {
                strongSelf.clearAuth()
                task.result = .success(provider)
            }
        }
        return task
    }
    
    // MARK: Private
    
    private func clearAuth() {
        guard auth != nil else {
            return
        }
        
        auth = nil
        userDefaults?.removeObject(forKey: Consts.AuthRefreshTokenUDKey)
        networkAdapter.cancelAllRequests()
    }
    
    // MARK: - Requests
    
    @discardableResult
    public func executePipeline(pipeline: Pipeline) -> BaasTask<Any> {
        return executePipeline(pipelines: [pipeline])
    }
    
    @discardableResult
    public func executePipeline(pipelines: [Pipeline]) -> BaasTask<Any> {
        let params = pipelines.map { $0.toJson }
        return performRequest(method: .post, endpoint: Consts.PipelinePath, parameters: params).continuationTask(parser: { (json) -> Any in
            let document = try Document(extendedJson: json)
            if let docResult = document[Consts.ResultKey] {
                return docResult
            }
            else {
                throw BaasError.responseParsingFailed(reason: "Unexpected result received - expected a json reponse with a 'result' key, found: \(json).")
            }
        })
    }
    
    // MARK: Private
    
    @discardableResult
    private func performRequest(method: NAHTTPMethod, endpoint: String, parameters: [[String : Any]]?, refreshOnFailure: Bool = true, useRefreshToken: Bool = false) -> BaasTask<[String : Any]> {
        let task = BaasTask<[String : Any]>()
        guard isAuthenticated else {
            task.result = .failure(BaasError.unauthorized(message: "Must first authenticate"))
            return task
        }
        
        let url = "\(baseUrl)\(appId)/\(endpoint)"
        let token = useRefreshToken ? refreshToken ?? String() : auth?.accessToken ?? String()
        networkAdapter.requestWithArray(url: url, method: method, parameters: parameters, headers: ["Authorization" : "Bearer \(token)"]).response(onQueue: DispatchQueue.global(qos: .utility), completionHandler: { [weak self] (response) in
            guard let strongSelf = self else {
                task.result = BaasResult.failure(BaasError.clientReleased)
                return
            }
            
            switch response {
            case .success(let value):
                strongSelf.handleSuccessfulResponse(withValue: value, method: method, endpoint: endpoint, parameters: parameters, refreshOnFailure: refreshOnFailure, task: task)
                
            case .failure(let error):
                task.result = .failure(error)
                
            }
        })
        
        return task
    }
    
    func handleSuccessfulResponse(withValue value: Any, method: NAHTTPMethod, endpoint: String, parameters: [[String : Any]]?, refreshOnFailure: Bool, task: BaasTask<[String : Any]>) {
        if let value = value as? [String : Any] {
            if let error = parseError(from: value) {
                switch error {
                case .serverError(let reason):
                    
                    // check if error is invalid session
                    if reason.isInvalidSession {
                        if refreshOnFailure {
                            handleInvalidSession(method: method, endpoint: endpoint, parameters: parameters, task: task)
                        }
                        else {
                            clearAuth()
                            task.result = .failure(error)
                        }
                    }
                    else {
                        task.result = .failure(error)
                    }
                default:
                    task.result = .failure(error)
                }
            }
            else {
                task.result = .success(value)
            }
        }
        else {
            task.result = .failure(BaasError.responseParsingFailed(reason: "Unexpected result received - expected json and received: \(value)"))
        }
    }
    
    private func getAuthFromSavedJwt() throws -> Auth? {
        if let authDicString = userDefaults?.object(forKey: Consts.AuthJwtUDKey) as? String,
            let authDicData = authDicString.data(using: .utf8) {
            
            if let authDic = try JSONSerialization.jsonObject(with: authDicData, options: []) as? [String: Any] {
                return try Auth(dictionary: authDic)
            }
        }
        
        return nil
    }
    
    // MARK: - Refresh Access Token
    
    private func handleInvalidSession(method: NAHTTPMethod, endpoint: String, parameters: [[String : Any]]?, task: BaasTask<[String : Any]>) {
        refreshAccessToken().response(onQueue: DispatchQueue.global(qos: .utility)) { [weak self] (result) in
            guard let strongSelf = self else {
                task.result = BaasResult.failure(BaasError.clientReleased)
                return
            }
            
            switch result {
            case .failure(let error):
                task.result = .failure(error)
                
            case .success:
                // retry once
                strongSelf.performRequest(method: method, endpoint: endpoint, parameters: parameters, refreshOnFailure: false)
                    .response(onQueue: DispatchQueue.global(qos: .utility)) { (result) in
                        switch result {
                        case .failure(let error):
                            task.result = .failure(error)
                            
                        case .success(let value):
                            task.result = .success(value)
                            
                        }
                }
                
            }
        }
    }
    
    private func refreshAccessToken() -> BaasTask<Void> {
        return performRequest(method: .post, endpoint: "\(Consts.AuthPath)/\(Consts.NewAccessTokenPath)", parameters: nil, refreshOnFailure: false, useRefreshToken: true).continuationTask(parser: { [weak self] (json) -> Void in
            guard let strongSelf = self else {
                throw BaasError.clientReleased
            }
            
            if let accessToken = json[Consts.AccessTokenKey] as? String {
                strongSelf.auth = strongSelf.auth?.auth(with: accessToken)
            }
            else {
                throw BaasError.responseParsingFailed(reason: "failed parsing access token from result: \(json).")
            }
        })
    }
    
    // MARK: - Error handling
    
    private func parseError(from value: [String : Any]) -> BaasError? {
        
        guard let errMsg = value[Consts.ErrorKey] as? String else {
            return nil
        }
        
        printLog(.error, text: "request failed. error: \(errMsg)")        
        
        if let errorCode = value[Consts.ErrorCodeKey] as? String {
            return BaasError.serverError(reason: BaasError.ServerErrorReason(errorCode: errorCode, errorMessage: errMsg))
        }
        
        return BaasError.serverError(reason: .other(message: errMsg))
    }
    
}
