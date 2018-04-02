import Foundation

public protocol APIAuthInfo: Decodable {
    var userId: String { get }
    var deviceId: String { get }
    var accessToken: String { get }
    var refreshToken: String { get }
}

public protocol ExtendedAuthInfo {
    var loggedInProviderType: String { get }
    var loggedInProviderName: String { get }
    var userProfile: StitchUserProfile { get }
}

public protocol AuthInfo: APIAuthInfo, ExtendedAuthInfo {
}

extension AuthInfo {

    public static func read(fromStorage storage: Storage) throws -> AuthInfo? {
        let authInfoAny = storage.value(forKey: "auth_info")

        guard let authData = authInfoAny as? Data else {
            return nil
        }

        return try JSONDecoder().decode(StoreAuthInfo.self, from: authData)
    }

    public func write(toStorage storage: inout Storage) throws {
        storage.set(try JSONEncoder().encode(StoreAuthInfo.init(withAuthInfo: self)),
                    forKey: "auth_info")
    }

    public static func clear(storage: inout Storage) {
        storage.set(nil, forKey: "auth_info")
    }

    func merge(withPartialInfo partialInfo: APIAuthInfo, fromOldInfo oldInfo: AuthInfo) -> AuthInfo {
        return StoreAuthInfo.init(withAPIAuthInfo: partialInfo,
                                  withExtendedAuthInfo: oldInfo)
    }

    func refresh(withNewAccessToken newAccessToken: APIAccessToken) -> AuthInfo {
        return StoreAuthInfo.init(withAuthInfo: self, withNewAPIAccessToken: newAccessToken)
    }
}
