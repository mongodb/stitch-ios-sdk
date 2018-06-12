import Foundation

/**
 * A class containing functionality to proactively refresh access tokens to prevent the server from getting too
 * many invalid session errors.
 */
class AccessTokenRefresher<T> where T: CoreStitchUser {
    // MARK: Properties

    /**
     * A weak reference to the `CoreStitchAuth` for which this refresher will attempt to refresh tokens.
     */
    private weak var authRef: CoreStitchAuth<T>?

    /**
     * The length of the interval for checking if a token refresh is necessary.
     */
    private let sleepMillis: Double

    /**
     * If the token is expiring within this number of seconds when an access token expiration check is made, the
     * refresher will attempt to proactively refresh the access token.
     */
    private let expirationWindowSeconds: Double

    // MARK: Initializer

    /**
     * A basic initializer, which sets the refresher's properties to the values provided in the parameters.
     */
    init(authRef: CoreStitchAuth<T>?,
         sleepMillis: UInt32 = 60000,
         expirationWindowSeconds: Double = 300.0) {
        self.authRef = authRef
        self.sleepMillis = Double(sleepMillis)
        self.expirationWindowSeconds = expirationWindowSeconds
    }

    // MARK: Functions

    /**
     * Infinitely loops, checking if a proactive token refresh is necessary, every `sleepMillis` milliseconds.
     * This should only be run on a standalone, non-main thread. If the `CoreStitchAuth` referenced in `authRef` is
     * deallocated, the loop will end.
     */
    public func run() {
        repeat {
            if !checkRefresh() {
                return
            }
            Thread.sleep(forTimeInterval: Date.init().timeIntervalSince1970 + sleepMillis)
        } while true
    }

    /**
     * Checks if the access token in the `CoreStitchAuth` referenced by `authRef` needs to be refreshed.
     *
     * - returns: false if `authRef` has been deallocated, true otherwise
     */
    @discardableResult
    internal func checkRefresh() -> Bool {
        guard let auth = authRef else { return false }
        guard auth.isLoggedIn else { return true }
        guard let accessToken = auth.authInfo?.accessToken else { return true }

        guard let expires = (try? JWT.init(fromEncodedJWT: accessToken))?.expires else {
            return true
        }

        // Check if it's time to refresh the access token
        if Date.init().timeIntervalSince1970 < expires - expirationWindowSeconds {
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
