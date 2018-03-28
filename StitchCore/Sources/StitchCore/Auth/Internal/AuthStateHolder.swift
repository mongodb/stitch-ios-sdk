import Foundation

internal struct AuthStateHolder {
    var apiAuthInfo: APIAuthInfo?
    var extendedAuthInfo: ExtendedAuthInfo?
    var authInfo: AuthInfo?

    var isLoggedIn: Bool {
        return apiAuthInfo != nil || authInfo != nil
    }

    var accessToken: String? {
        return apiAuthInfo?.accessToken ?? authInfo?.accessToken
    }

    var refreshToken: String? {
        return apiAuthInfo?.refreshToken ?? authInfo?.refreshToken
    }

    var userId: String? {
        return apiAuthInfo?.userId ?? authInfo?.userId
    }

    mutating func clearState() {
        self.apiAuthInfo = nil
        self.extendedAuthInfo = nil
        self.authInfo = nil
    }
}
