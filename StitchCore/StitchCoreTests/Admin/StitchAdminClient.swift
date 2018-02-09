import Foundation
import PromiseKit
import ExtendedJson
@testable import StitchCore

public final class StitchAdminClientFactory {
    public static func create(baseUrl: String = Consts.defaultServerUrl) -> Promise<StitchAdminClient> {
        return Promise(value: StitchAdminClient.init(baseUrl: baseUrl))
    }
}

public class StitchAdminClient {
    private static let apiPath = "/api/admin/v3.0"

    let baseUrl: String
    let httpClient: StitchHTTPClient

    fileprivate init(baseUrl: String) {
        self.baseUrl = baseUrl
        self.httpClient = StitchHTTPClient.init(baseUrl: baseUrl,
                                                 apiPath: StitchAdminClient.apiPath,
                                                 networkAdapter: StitchNetworkAdapter(),
                                                 storage: MemoryStorage(),
                                                 storageKeys: StorageKeys.init(suiteName: "__admin__"))
    }

    func apps(withGroupId groupId: String) -> AppsResource {
        return AppsResource.init(httpClient: httpClient, url: "/groups/\(groupId)/apps")
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
