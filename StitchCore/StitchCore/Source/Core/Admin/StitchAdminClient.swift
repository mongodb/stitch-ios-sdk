//
//  StitchAdminClient.swift
//  StitchCore
//
//  Created by Jason Flax on 12/18/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import PromiseKit
import ExtendedJson

internal protocol Endpoint {
    var url: String { get }
    var httpClient: StitchHTTPClient { get }
}
internal protocol List: Endpoint { associatedtype Model: Decodable }
extension List {
    public func list() -> Promise<[Model]> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
        }.flatMap {
            return try JSONDecoder().decode([Model].self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}
internal protocol Get: Endpoint { associatedtype Model: Decodable }
extension Get {
    public func get() -> Promise<Model> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
        }.flatMap {
            return try JSONDecoder().decode(Model.self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}
internal protocol Remove: Endpoint { }
extension Remove {
    public func remove() -> Promise<Any> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
            $0.method = .delete
        }
    }
}
internal protocol Create: Endpoint {
    associatedtype CreatorModel: Encodable
    associatedtype Model: Decodable
}
extension Create {
    public func create(data: CreatorModel) -> Promise<Model> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
            $0.method = .post
            try $0.encode(withData: data)
        }.flatMap {
            return try JSONDecoder().decode(Model.self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}
internal protocol Update: Endpoint { associatedtype Model: Codable }
extension Update {
    public func update(data: Model) -> Promise<Model> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
            $0.method = .put
            try $0.encode(withData: data)
        }.flatMap {
            return try JSONDecoder().decode(Model.self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}
internal protocol Enable: Endpoint { }
extension Enable {
    public func enable() -> Promise<Any> {
        return self.httpClient.doRequest {
            $0.endpoint = "\(self.url)/enable"
            $0.method = .put
        }
    }
}
internal protocol Disable: Endpoint { }
extension Disable {
    public func disable() -> Promise<Any> {
        return self.httpClient.doRequest {
            $0.endpoint = "\(self.url)/disable"
            $0.method = .put
        }
    }
}

public final class ValueEndpoint: Endpoint, Get, Remove, Update {
    typealias Model = ValueView

    internal let httpClient: StitchHTTPClient
    internal let url: String

    fileprivate init(httpClient: StitchHTTPClient,
                     valueUrl: String) {
        self.httpClient = httpClient
        self.url = valueUrl
    }
}

public final class ValuesEndpoint: Endpoint, List, Create {
    typealias CreatorModel = ValueView

    typealias Model = ValueView

    internal let httpClient: StitchHTTPClient
    internal let url: String

    fileprivate init(httpClient: StitchHTTPClient,
                     appUrl: String) {
        self.httpClient = httpClient
        self.url = appUrl
    }

    func value(withId id: String) -> ValueEndpoint {
        return ValueEndpoint.init(httpClient: self.httpClient, valueUrl: "\(url)/\(id)")
    }
}

public final class AppEndpoint: Endpoint, Get, Remove {
    typealias Model = AppView

    internal let httpClient: StitchHTTPClient
    internal let url: String

    fileprivate init(httpClient: StitchHTTPClient,
                     appUrl: String) {
        self.httpClient = httpClient
        self.url = appUrl
    }

    lazy var values: ValuesEndpoint =
        ValuesEndpoint.init(httpClient: self.httpClient, appUrl: "\(self.url)/values")

    lazy var authProviders: AuthProvidersEndpoint =
        AuthProvidersEndpoint.init(httpClient: self.httpClient,
                                   authProvidersUrl: "\(self.url)/auth_providers")

    lazy var users: UsersEndpoint =
        UsersEndpoint.init(httpClient: self.httpClient,
                           usersUrl: "\(self.url)/users")
}

public final class AppsEndpoint: Endpoint, List {
    typealias Model = AppView

    let httpClient: StitchHTTPClient
    let url: String

    fileprivate init(httpClient: StitchHTTPClient,
                     groupUrl: String) {
        self.httpClient = httpClient
        self.url = groupUrl
    }

    func create(name: String, defaults: Bool = false) -> Promise<AppView> {
        return httpClient.doRequest {
            $0.endpoint = "\(self.url)?defaults=\(defaults)"
            $0.method = .post
            try $0.encode(withData: ["name": name])
        }.flatMap {
            return try JSONDecoder().decode(Model.self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }

    func app(withAppId appId: String) -> AppEndpoint {
        return AppEndpoint.init(httpClient: self.httpClient, appUrl: "\(url)/\(appId)")
    }
}
struct PushNotificationView: Codable {
}
struct IncomingWebhookView: Codable {
}
struct RuleView: Codable {
}
struct ServiceInputView: Codable {
}
struct ValueView: Codable {
}
struct AppView: Codable {
    enum CodingKeys: String, CodingKey {
        case name, id = "_id", clientAppId = "client_app_id"
    }
    let id: String
    let name: String
    let clientAppId: String
}

public final class StitchAdminClientFactory {
    public static func create(baseUrl: String = Consts.DefaultBaseUrl) -> Promise<StitchAdminClient> {
        return Promise(value: StitchAdminClient.init(baseUrl: baseUrl))
    }
}

public class StitchAdminClient {
    let baseUrl: String
    let httpClient: StitchHTTPClient

    fileprivate init(baseUrl: String) {
        self.baseUrl = baseUrl
        self.httpClient = StitchHTTPClient.init(baseUrl: baseUrl,
                                                apiPath: "/api/admin/v3.0",
                                                networkAdapter: StitchNetworkAdapter())
    }

    func apps(withGroupId groupId: String) -> AppsEndpoint {
        return AppsEndpoint.init(httpClient: httpClient, groupUrl: "/groups/\(groupId)/apps")
    }

    /**
     * @return A {@link Document} representing the information for this device
     * from the context of this app.
     */
    private func getDeviceInfo() -> Document {
        var info = Document()

        if let deviceId = self.httpClient.authInfo?.deviceId {
            info[DeviceFields.deviceId.rawValue] = deviceId
        }

        info[DeviceFields.appVersion.rawValue] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        info[DeviceFields.appId.rawValue] = Bundle.main.bundleIdentifier
        info[DeviceFields.platform.rawValue] = "ios"
        info[DeviceFields.platformVersion.rawValue] = UIDevice.current.systemVersion

        return info
    }

    private func getAuthRequest(provider: AuthProvider) -> Document {
        var request = provider.payload
        let options: Document = [
            StitchClient.AuthFields.device.rawValue: getDeviceInfo()
        ]
        request[StitchClient.AuthFields.options.rawValue] = options
        return request
    }

    func authenticate(provider: AuthProvider) -> Promise<UserId> {
        return self.httpClient.doRequest { request in
            request.method = .post
            request.endpoint = "/auth/providers/\(provider.type.rawValue)/login"
            request.isAuthenticatedRequest = false
            try request.encode(withData: self.getAuthRequest(provider: provider))
        }.flatMap { [weak self] any in
            guard let strongSelf = self else { throw StitchError.clientReleased }
            let authInfo = try JSONDecoder().decode(AuthInfo.self,
                                                    from: JSONSerialization.data(withJSONObject: any))
            strongSelf.httpClient.authInfo = authInfo
            return authInfo.userId
        }
    }

    /**
     Fetch the current user profile, containing all user info. Can fail.

     - Returns: A Promise containing profile of the given user
     */
    @discardableResult
    public func fetchUserProfile() -> Promise<UserProfile> {
        return self.httpClient.doRequest {
            $0.endpoint = "/auth/profile"
            $0.refreshOnFailure = false
            $0.useRefreshToken = false
        }.flatMap {
                return try JSONDecoder().decode(UserProfile.self,
                                                from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}
