//
//  Auth.swift
//  StitchCore
//
//  Created by Jason Flax on 10/18/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public class Auth {
    private let stitchClient: StitchClient
    
    public internal(set) var authInfo: AuthInfo
    
    public func createSelfApiKey(name: String) -> StitchTask<ApiKey> {
        let task = StitchTask<ApiKey>()

        stitchClient.performRequest(method: .post,
                                    endpoint: Consts.UserProfileApiKeyPath,
                                    parameters: [["name": name]],
                                    refreshOnFailure: true,
                                    useRefreshToken: true)
            .response { (res) in
                switch res {
                case.success(let value):
                    guard let apiKey = try? JSONDecoder().decode(ApiKey.self,
                                                                 from: value as! Data)  else {
                        task.result = .failure(StitchError.responseParsingFailed(
                            reason: "api key did not contain valid info")
                        )
                        return
                    }
                    task.result = .success(apiKey)
                case .failure(let error):
                    task.result = .failure(error)
                }
        }
        
        return task
    }
    
    public func fetchSelfApiKey(id: String) -> StitchTask<ApiKey> {
        let task = StitchTask<ApiKey>()
        
        stitchClient.performRequest(method: .get,
                                    endpoint: "\(Consts.UserProfileApiKeyPath)/\(id)",
                                    parameters: nil,
                                    refreshOnFailure: true,
                                    useRefreshToken: true)
            .response { (res) in
                switch res {
                case.success(let value):
                    guard let apiKey = try? JSONDecoder().decode(ApiKey.self,
                                                                 from: value as! Data)  else {
                        task.result = .failure(StitchError.responseParsingFailed(
                            reason: "api key did not contain valid info")
                        )
                        return
                    }
                    task.result = .success(apiKey)
                case .failure(let error):
                    task.result = .failure(error)
                }
        }
        
        return task
    }
    
    public func fetchSelfApiKeys() -> StitchTask<[ApiKey]> {
        let task = StitchTask<[ApiKey]>()
        
        stitchClient.performRequest(method: .get,
                                    endpoint: "\(Consts.UserProfileApiKeyPath)",
            parameters: nil,
            refreshOnFailure: true,
            useRefreshToken: true)
            .response { (res) in
                switch res {
                case.success(let value):
                    guard let apiKey = try? JSONDecoder().decode([ApiKey].self,
                                                                 from: value as! Data) else {
                        task.result = .failure(StitchError.responseParsingFailed(
                            reason: "api key did not contain valid info")
                        )
                        return
                    }
                    task.result = .success(apiKey)
                case .failure(let error):
                    task.result = .failure(error)
                }
        }
        
        return task
    }
    
    public func deleteSelfApiKey(id: String) -> StitchTask<Bool> {
        let task = StitchTask<Bool>()
        
        stitchClient.performRequest(method: .delete,
                                    endpoint: "\(Consts.UserProfileApiKeyPath)/\(id)",
            parameters: nil,
            refreshOnFailure: true,
            useRefreshToken: true)
            .response { (res) in
                switch res {
                case.success:
                    task.result = .success(true)
                case .failure(let error):
                    task.result = .failure(error)
                }
        }
        
        return task
    }
    
    private func enableDisableApiKey(id: String, shouldEnable: Bool) -> StitchTask<Bool> {
        let task = StitchTask<Bool>()
        
        stitchClient.performRequest(method: .put,
                                    endpoint: "\(Consts.UserProfileApiKeyPath)/\(id)/\(shouldEnable ? "enable" : "disable")",
            parameters: nil,
            refreshOnFailure: true,
            useRefreshToken: true)
            .response { (res) in
                switch res {
                case.success:
                    task.result = .success(true)
                case .failure(let error):
                    task.result = .failure(error)
                }
        }
        
        return task
    }
    
    public func enableApiKey(id: String) ->  StitchTask<Bool>{
        return self.enableDisableApiKey(id: id, shouldEnable: true)
    }
    
    public func disableApiKey(id: String) -> StitchTask<Bool> {
        return self.enableDisableApiKey(id: id, shouldEnable: false)
    }
    
    /**
     Fetch the current user profile, containing all user info. Can fail.
     
     - Returns: A StitchTask containing profile of the given user
     */
    @discardableResult
    public func fetchUserProfile() -> StitchTask<UserProfile> {
        let task = StitchTask<UserProfile>()
        stitchClient.performRequest(method: .get,
                                    endpoint: Consts.UserProfilePath,
                                    parameters: nil,
                                    refreshOnFailure: false,
                                    useRefreshToken: false)
            .response(onQueue: DispatchQueue.global(qos: .utility)) { [weak self] (result) in
                        guard let strongSelf = self else {
                            task.result = StitchResult.failure(StitchError.clientReleased)
                            return
                        }
                        
                        switch result {
                        case .success(let value):
                            if let value = value as? [String : Any] {
                                if let error = strongSelf.stitchClient.parseError(from: value) {
                                    task.result = .failure(error)
                                }
                                else if let user = try? UserProfile(dictionary: value) {
                                    task.result = .success(user)
                                } else {
                                    task.result = StitchResult.failure(StitchError.clientReleased)
                                }
                            }
                        case .failure(let error):
                            task.result = .failure(error)
                        }
        }
        
        return task
    }
    
    internal init(stitchClient: StitchClient, authInfo: AuthInfo) {
        self.stitchClient = stitchClient
        self.authInfo = authInfo
    }
}
