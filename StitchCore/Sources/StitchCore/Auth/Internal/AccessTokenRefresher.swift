import Foundation

class AccessTokenRefresher<T> where T: CoreStitchUser {
    private weak var authRef: CoreStitchAuth<T>?
    private let sleepMillis: Double
    private let expirationWindowSeconds: Double

    init(authRef: CoreStitchAuth<T>?,
         sleepMillis: UInt32 = 60000,
         expirationWindowSeconds: Double = 300.0) {
        self.authRef = authRef
        self.sleepMillis = Double(sleepMillis)
        self.expirationWindowSeconds = expirationWindowSeconds
    }

    public func run() {
        repeat {
            if !checkRefresh() {
                return
            }
            Thread.sleep(forTimeInterval: Date.init().timeIntervalSince1970 + sleepMillis)
        } while true
    }

    @discardableResult
    internal func checkRefresh() -> Bool {
        guard let auth = authRef else { return false }
        guard auth.isLoggedIn else { return true }
        guard let accessToken = auth.authInfo?.accessToken else { return true }

        guard let expiration = (try? DecodedJWT.init(jwt: accessToken))?.expiration else {
            return true
        }

        // Check if it's time to refresh the access token
        if Date.init().timeIntervalSince1970 <
            expiration.timeIntervalSince1970 - expirationWindowSeconds {
            return true
        }

        do {
            try auth.refreshAccessToken()
        } catch let err {
            NSLog("Error refreshing access token: %@", err.localizedDescription)
        }
        return true
    }
}
