import Foundation
import PromiseKit
import ExtendedJson
@testable import StitchCore

// Any endpoint that can be described with basic
// CRUD operations
internal protocol Endpoint {
    /// absolute url to this endpoint
    var url: String { get }
    // stitch http client for making requests
    var httpClient: StitchHTTPClient { get }
}

// Adds an endpoint method that GETs some list
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

// Adds an endpoint method that GETs some id
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

// Adds an endpoint method that DELETEs some id
internal protocol Remove: Endpoint { }
extension Remove {
    public func remove() -> Promise<Any> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
            $0.method = .delete
        }
    }
}

// Adds an endpoint method that POSTs new data
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

// Adds an endpoint method that PUTs some data
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

// Adds an endpoint that enables a given resource
internal protocol Enable: Endpoint { }
extension Enable {
    public func enable() -> Promise<Any> {
        return self.httpClient.doRequest {
            $0.endpoint = "\(self.url)/enable"
            $0.method = .put
        }
    }
}

// Adds an endpoint that disables a given resource
internal protocol Disable: Endpoint { }
extension Disable {
    public func disable() -> Promise<Any> {
        return self.httpClient.doRequest {
            $0.endpoint = "\(self.url)/disable"
            $0.method = .put
        }
    }
}

public final class StitchAdminClientFactory {
    public static func create(baseUrl: String = Consts.defaultServerUrl) -> Promise<StitchAdminClient> {
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
                                                networkAdapter: StitchNetworkAdapter(),
                                                storage: MemoryStorage(),
                                                storageKeys: StorageKeys.init(suiteName: "__admin__"))
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

    /// Fetch the current user profile, containing all user info. Can fail.
    /// - returns: A Promise containing profile of the given user
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
