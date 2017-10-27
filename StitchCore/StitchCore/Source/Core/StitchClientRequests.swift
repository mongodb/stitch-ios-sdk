//
//  StitchClientRequests.swift
//  StitchCore
//
//  Created by Jason Flax on 10/22/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import StitchLogger
import ExtendedJson

extension StitchClient {
    internal func getAuthFromSavedJwt() throws -> AuthInfo {
        guard userDefaults?.bool(forKey: Consts.IsLoggedInUDKey) == true else {
            throw StitchError.unauthorized(message: "must be logged in")
        }

        do {
            if let authDicString = readToken(withKey: Consts.AuthJwtKey),
                let authDicData = authDicString.data(using: .utf8) {
                return try JSONDecoder().decode(AuthInfo.self, from: authDicData)
            }
        } catch {
            printLog(.error, text: "Failed reading auth token from keychain")
        }

        throw StitchError.unauthorized(message: "authorization failure")
    }

    private func readToken(withKey key: String) -> String? {
        if isSimulator {
            printLog(.debug, text: "Falling back to reading token from UserDefaults because of simulator bug")
            return userDefaults?.object(forKey: key) as? String
        } else {
            do {
                let keychainItem = KeychainPasswordItem(service: Consts.AuthKeychainServiceName, account: key)
                let token = try keychainItem.readPassword()
                return token
            } catch {
                printLog(.warning, text: "failed reading auth token from keychain: \(error)")
                return nil
            }
        }
    }

    private var refreshToken: String? {
        guard isAuthenticated else {
            return nil
        }

        return readToken(withKey: Consts.AuthRefreshTokenKey)
    }

    private func refreshAccessToken() -> StitchTask<Void> {
        return performRequest(
            method: .post,
            endpoint: "\(Consts.AuthPath)/\(Consts.NewAccessTokenPath)",
            refreshOnFailure: false,
            useRefreshToken: true,
            responseType: [String: String].self).then(parser: { [weak self] (json) -> Void in
                guard let strongSelf = self else {
                    throw StitchError.clientReleased
                }

                guard let accessToken = json[Consts.AccessTokenKey],
                    let auth = strongSelf.auth else {
                        throw StitchError.unauthorized(message: "not authenticated")
                }

                auth.authInfo = auth.authInfo.auth(with: accessToken)
            })
    }

    private func refreshAccessTokenAndRetry<T>(method: NAHTTPMethod,
                                               endpoint: String,
                                               parameters: Encodable?,
                                               task: StitchTask<T>) where T: Decodable {
        refreshAccessToken().response(onQueue: DispatchQueue.global(qos: .utility)) { [weak self] (innerTask) in
            guard let strongSelf = self else {
                task.result = StitchResult.failure(StitchError.clientReleased)
                return
            }

            switch innerTask.result {
            case .failure(let error):
                task.result = .failure(error)
            case .success:
                // retry once
                strongSelf.performRequest(method: method,
                                          endpoint: endpoint,
                                          parameters: parameters,
                                          refreshOnFailure: false,
                                          responseType: T.self)
                    .response(onQueue: DispatchQueue.global(qos: .utility)) { innerTask in
                        switch innerTask.result {
                        case .failure(let error):
                            task.result = .failure(error)
                        case .success(let value):
                            task.result = .success(value)
                        }
                }
            }
        }
    }

    private func url(withEndpoint endpoint: String) -> String {
        return "\(baseUrl)\(Consts.ApiPath)\(appId)/\(endpoint)"
    }

    @discardableResult
    internal func performRequest<D>(method: NAHTTPMethod,
                                    endpoint: String,
                                    isAuthenticatedRequest: Bool = true,
                                    refreshOnFailure: Bool = true,
                                    useRefreshToken: Bool = false,
                                    responseType: D.Type) -> StitchTask<D> where D: Decodable {
        return self.performRequest(method: method,
                                   endpoint: endpoint,
                                   isAuthenticatedRequest: isAuthenticatedRequest,
                                   parameters: [String: String](),
                                   refreshOnFailure: refreshOnFailure,
                                   useRefreshToken: useRefreshToken,
                                   responseType: responseType)
    }

    @discardableResult
    internal func performRequest<D, E>(method: NAHTTPMethod,
                                       endpoint: String,
                                       isAuthenticatedRequest: Bool = true,
                                       parameters: E? = nil,
                                       refreshOnFailure: Bool = true,
                                       useRefreshToken: Bool = false,
                                       responseType: D.Type) -> StitchTask<D> where D: Decodable, E: Encodable {
        let task = StitchTask<D>()
        if isAuthenticatedRequest && !isAuthenticated {
            task.result = .failure(StitchError.unauthorized(message: "Must first authenticate"))
            return task
        }

        if isAuthenticatedRequest && !useRefreshToken && (self.auth?.isAccessTokenExpired() ?? false) {
            self.refreshAccessTokenAndRetry(method: method,
                                            endpoint: endpoint,
                                            parameters: parameters,
                                            task: task)
            return task
        }

        let bearer = useRefreshToken ? refreshToken ?? String() : auth?.authInfo.accessToken?.token ?? String()
        networkAdapter.requestWithJsonEncoding(url: self.url(withEndpoint: endpoint),
                                               method: method,
                                               parameters: parameters,
                                               headers: isAuthenticatedRequest ?
                                                ["Authorization": "Bearer \(bearer)"] : nil)
            .response(onQueue: DispatchQueue.global(qos: .utility),
                      completionHandler: { [weak self] internalTask in
                        guard let strongSelf = self else {
                            task.result = StitchResult.failure(StitchError.clientReleased)
                            return
                        }

                        switch internalTask.result {
                        case .success(let value):
                            guard let data = value,
                                let json = try? JSONSerialization.jsonObject(with: data,
                                                                             options: []) as? [String: Any] else {
                                return task.result = .failure(
                                    StitchError.responseParsingFailed(reason: "Received no valid data from server"))
                            }

                            if let json = json, let error = strongSelf.parseError(from: json) {
                                switch error {
                                case .serverError(let reason):
                                    // check if error is invalid session
                                    if reason.isInvalidSession {
                                        if refreshOnFailure {
                                            strongSelf.refreshAccessTokenAndRetry(method: method,
                                                                                  endpoint: endpoint,
                                                                                  parameters: parameters,
                                                                                  task: task)
                                        } else {
                                            try? strongSelf.clearAuth()
                                            task.result = .failure(error)
                                        }
                                    } else {
                                        task.result = .failure(error)
                                    }
                                default:
                                    task.result = .failure(error)
                                }
                                return
                            }

                            guard let payload: D = {
                                switch D.self {
                                case let superType as ExtendedJsonRepresentable.Type:
                                    let ext = try? superType.fromExtendedJson(xjson: json as Any)
                                    guard let d = ext as? D else { return nil }
                                    return d
                                default:
                                    return try? JSONDecoder().decode(D.self, from: data)
                                }
                            }() else {
                                return task.result = .failure(
                                    StitchError.responseParsingFailed(reason: "invalid error"))
                            }

                            task.result = .success(payload)
                        case .failure(let error):
                            task.result = .failure(error)
                        }
            })

        return task
    }

    internal func parseError(from value: [String: Any]) -> StitchError? {
        guard let errMsg = value[Consts.ErrorKey] as? String else {
            return nil
        }

        printLog(.error, text: "request failed. error: \(errMsg)")

        if let errorCode = value[Consts.ErrorCodeKey] as? String {
            return StitchError.serverError(reason: StitchError.ServerErrorReason(errorCode: errorCode,
                                                                                 errorMessage: errMsg))
        }

        return StitchError.serverError(reason: .other(message: errMsg))
    }
}
