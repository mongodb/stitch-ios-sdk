import Foundation

import ExtendedJson
import StitchLogger
import Security

public struct Consts {
    public static let DefaultBaseUrl =   "https://stitch.mongodb.com"
    static let ApiPath =                 "/api/client/v1.0/app/"

    //User Defaults
    static let UserDefaultsName =        "com.mongodb.stitch.sdk.UserDefaults"
    static let IsLoggedInUDKey =         "StitchCoreIsLoggedInUserDefaultsKey"

    //keychain
    static let AuthJwtKey =              "StitchCoreAuthJwtKey"
    static let AuthRefreshTokenKey =     "StitchCoreAuthRefreshTokenKey"
    static let AuthKeychainServiceName = "com.mongodb.stitch.sdk.authentication"

    //keys
    static let ResultKey =               "result"
    static let AccessTokenKey =          "accessToken"
    static let RefreshTokenKey =         "refreshToken"
    static let ErrorKey =                "error"
    static let ErrorCodeKey =            "errorCode"

    //api
    static let AuthPath =                "auth"
    static let UserProfilePath =         "auth/me"
    static let UserProfileApiKeyPath =   "auth/me/api_keys"

    static let NewAccessTokenPath =      "newAccessToken"
    static let PipelinePath =            "pipeline"
    static let PushPath =                "push"
}

/// A StitchClient is responsible for handling the overall interaction with all Stitch services.
public class StitchClient: StitchClientType {
    // MARK: - Properties
    /// Id of the current application
    public var appId: String

    internal var baseUrl: String
    internal let networkAdapter: NetworkAdapter

    internal let userDefaults = UserDefaults(suiteName: Consts.UserDefaultsName)

    private var authProvider: AuthProvider?
    private var authDelegates = [AuthDelegate?]()

    /// The currently authenticated user (if authenticated).
    public private(set) var auth: Auth? {
        didSet {
            if let newValue = auth {
                // save auth persistently
                userDefaults?.set(true, forKey: Consts.IsLoggedInUDKey)

                do {
                    let jsonData = try JSONEncoder().encode(newValue.authInfo)
                    guard let jsonString = String(data: jsonData,
                                                  encoding: .utf8) else {
                        printLog(.error, text: "Error converting json String to Data")
                        return
                    }

                    save(token: jsonString, withKey: Consts.AuthJwtKey)
                } catch let error as NSError {
                    printLog(.error,
                             text: "failed saving auth to keychain, array to JSON conversion failed: " +
                                error.localizedDescription)
                }
            } else {
                // remove from keychain
                try? deleteToken(withKey: Consts.AuthJwtKey)
                userDefaults?.set(false, forKey: Consts.IsLoggedInUDKey)
            }
        }
    }

    /// Whether or not the client is currently authenticated
    public var isAuthenticated: Bool {
        guard auth == nil else {
            return true
        }

        do {
            auth?.authInfo = try getAuthFromSavedJwt()
        } catch {
            printLog(.error, text: error.localizedDescription)
        }

        onLogin()
        return auth != nil
    }

    internal var isSimulator: Bool {
        /*
         This is computed in a separate variable due to a compiler warning when the check
         is done directly inside the 'if' statement, indicating that either the 'if'
         block or the 'else' block will never be executed - depending whether the build
         target is a simulator or a device.
         */
        return TARGET_OS_SIMULATOR != 0
    }

    // MARK: - Init
    /**
        Create a new object to interact with Stitch
        - Parameters: 
            - appId:  The App ID for the Stitch app.
            - baseUrl: The base URL of the Stitch Client API server.
            - networkAdapter: Optional interface if AlamoFire is not desired.
     */
    public init(appId: String,
                baseUrl: String = Consts.DefaultBaseUrl,
                networkAdapter: NetworkAdapter = StitchNetworkAdapter()) {
        self.appId = appId
        self.baseUrl = baseUrl
        self.networkAdapter = networkAdapter
    }

    // MARK: - Auth

    /**
     Fetches all available auth providers for the current app.
     
     - Returns: A task containing AuthProviderInfo that can be resolved
     on completion of the request.
     */
    @discardableResult
    public func fetchAuthProviders() -> StitchTask<AuthProviderInfo> {
        return self.performRequest(method: .get,
                                   endpoint: Consts.AuthPath,
                                   isAuthenticatedRequest: false,
                                   responseType: AuthProviderInfo.self)
            .response(onQueue: DispatchQueue.global(qos: .utility)) { _ in }
    }

    /**
     Registers the current user using email and password.
     
     - parameter email: email for the given user
     - parameter password: password for the given user
     - returns: A task containing whether or not registration was successful.
     */
    @discardableResult
    public func register(email: String, password: String) -> StitchTask<Void> {
        let provider = EmailPasswordAuthProvider(username: email, password: password)
        return self.performRequest(method: .post,
                                   endpoint: "\(Consts.AuthPath))/\(provider.type)/\(provider.name)/register",
                                   isAuthenticatedRequest: false,
                                   parameters: ["email": email, "password": password],
                                   responseType: [String: String].self).then { _ in return }
    }

    /**
     * Confirm a newly registered email in this context
     * - parameter token: confirmation token emailed to new user
     * - parameter tokenId: confirmation tokenId emailed to new user
     * - returns: A task containing whether or not the email was confirmed successfully
     */
    @discardableResult
    public func emailConfirm(token: String, tokenId: String) -> StitchTask<Void> {
        return self.performRequest(method: .post,
                                   endpoint: Consts.AuthPath + "/local/userpass/confirm",
                                   isAuthenticatedRequest: false,
                                   parameters: ["token": token, "tokenId": tokenId],
                                   responseType: [String: String].self).then { _ in return }
    }

    /**
     * Send a confirmation email for a newly registered user
     * - parameter email: email address of user
     * - returns: A task containing whether or not the email was sent successfully.
     */
    @discardableResult
    public func sendEmailConfirm(toEmail email: String) -> StitchTask<Void> {
        return self.performRequest(method: .post,
                                   endpoint: Consts.AuthPath + "/local/userpass/confirm/send",
                                   isAuthenticatedRequest: false,
                                   parameters: ["email": email],
                                   responseType: [String: String].self).then { _ in return }
    }

    /**
     * Reset a given user's password
     * - parameter token: token associated with this user
     * - parameter tokenId: id of the token associated with this user
     * - returns: A task containing whether or not the reset was successful
     */
    @discardableResult
    public func resetPassword(token: String, tokenId: String) -> StitchTask<Void> {
        return self.performRequest(method: .post,
                                   endpoint: Consts.AuthPath + "/local/userpass/reset",
                                   isAuthenticatedRequest: false,
                                   parameters: ["token": token, "tokenId": tokenId],
                                   responseType: [String: String].self).then { _ in return }
    }

    /**
     * Send a reset password email to a given email address
     * - parameter email: email address to reset password for
     * - returns: A task containing whether or not the reset email was sent successfully
     */
    @discardableResult
    public func sendResetPassword(toEmail email: String) -> StitchTask<Void> {
        return self.performRequest(method: .post,
                                   endpoint: Consts.AuthPath + "/local/userpass/reset/send",
                                   isAuthenticatedRequest: false,
                                   parameters: ["email": email],
                                   responseType: [String: String].self).then { _ in return }
    }

    /**
     Logs the current user in anonymously.
     
     - Returns: A task containing whether or not the login as successful
     */
    @discardableResult
    public func anonymousAuth() -> StitchTask<AuthInfo> {
        return login(withProvider: AnonymousAuthProvider())
    }

    /**
     Logs the current user in using a specific auth provider.
     
     - Parameters:
     - withProvider: The provider that will handle the login.
     - link: Whether or not to link a new auth provider.
     - Returns: A task containing whether or not the login as successful
     */
    @discardableResult
    public func login(withProvider provider: AuthProvider) -> StitchTask<AuthInfo> {
        self.authProvider = provider

        if isAuthenticated, let auth = auth {
            printLog(.info, text: "Already logged in, using cached token.")
            return StitchTask<AuthInfo>.withSuccess(auth.authInfo)
        }

        return self.performRequest(method: .post,
                                   endpoint: Consts.AuthPath + "/\(provider.type)/\(provider.name)",
                                   isAuthenticatedRequest: false,
                                   parameters: self.getAuthRequest(provider: provider),
                                   responseType: AuthInfo.self)
            .response { [weak self] task in
                guard let authInfo = task.result.value,
                    let strongSelf = self else {
                    return
                }

                strongSelf.auth = Auth(stitchClient: strongSelf, authInfo: authInfo)
        }
    }

    /**
     * Logs out the current user.
     *
     * - returns: A task that can be resolved upon completion of logout.
     */
    @discardableResult
    public func logout() -> StitchTask<Void> {
        if !isAuthenticated {
            printLog(.info, text: "Tried logging out while there was no authenticated user found.")
            return StitchTask<Void>(value: Void())
        }

        return self.performRequest(method: .delete,
                                   endpoint: Consts.AuthPath,
                                   refreshOnFailure: false,
                                   useRefreshToken: true,
                                   responseType: [String: String].self).then { _ in return }
    }

    // MARK: Private
    internal func clearAuth() throws {
        guard auth != nil else {
            return
        }

        onLogout()

        auth = nil

        try deleteToken(withKey: Consts.AuthRefreshTokenKey)

        networkAdapter.cancelAllRequests()
    }

    enum AuthFields: String {
        case accessToken, options, device
    }

    /**
     * @return A {@link Document} representing the information for this device
     * from the context of this app.
     */
    private func getDeviceInfo() -> BsonDocument {
        var info = BsonDocument()

        if let deviceId = auth?.authInfo.deviceId {
            info[DeviceFields.deviceId.rawValue] = deviceId
        }

        info[DeviceFields.appVersion.rawValue] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        info[DeviceFields.appId.rawValue] = Bundle.main.bundleIdentifier
        info[DeviceFields.platform.rawValue] = "ios"
        info[DeviceFields.platformVersion.rawValue] = UIDevice.current.systemVersion

        return info
    }

    /**
     * -parameter provider: The provider that will handle authentication.
     * -returns: A dict representing all information required for
     *              an auth request against a specific provider.
     */
    private func getAuthRequest(provider: AuthProvider) -> BsonDocument {
        var request = provider.payload
        let options: BsonDocument = [
            AuthFields.device.rawValue: getDeviceInfo()
        ]
    	request[AuthFields.options.rawValue] = options
        return request
    }

    // MARK: - Requests

    /**
     * Executes a pipeline with the current app.
     *
     * - parameter stages: The stages to execute as a contiguous pipeline.
     * - returns: A task containing the result of the pipeline that can be resolved on completion
     * of the execution.
     */
    @discardableResult
    public func executePipeline(pipeline: Pipeline) -> StitchTask<BsonDocument> {
        return executePipeline(pipelines: [pipeline])
    }

    /**
     * Executes a pipeline with the current app.
     *
     * - parameter pipeline: The pipeline to execute.
     * - returns: A task containing the result of the pipeline that can be resolved on completion
     * of the execution.
     */
    @discardableResult
    public func executePipeline(pipelines: [Pipeline]) -> StitchTask<BsonDocument> {
        return performRequest(method: NAHTTPMethod.post,
                              endpoint: Consts.PipelinePath,
                              parameters: pipelines,
                              responseType: BsonDocument.self).response { task in
            switch task.result {
            case .success(let document):
                if let docResult = document[Consts.ResultKey] as? BsonDocument {
                    task.result = .success(docResult)
                } else {
                        task.result = .failure(
                            StitchError.responseParsingFailed(
                            reason: "Unexpected result received - expected a json reponse" +
                            "with a 'result' key, found: \(document)."))
                }
            case .failure(let err):
                task.result = .failure(err)
            }
        }
    }

    // MARK: - Token operations
    private func save(token: String, withKey key: String) {
        if isSimulator {
            printLog(.debug, text: "Falling back to saving token in UserDefaults because of simulator bug")
            userDefaults?.set(token, forKey: key)
        } else {
            do {
                let keychainItem = KeychainPasswordItem(service: Consts.AuthKeychainServiceName, account: key)
                try keychainItem.savePassword(token)
            } catch {
                printLog(.warning, text: "failed saving token to keychain: \(error)")
            }
        }
    }

    private func deleteToken(withKey key: String) throws {
        if isSimulator {
            printLog(.debug, text: "Falling back to deleting token from UserDefaults because of simulator bug")
            userDefaults?.removeObject(forKey: key)
        } else {
            do {
                let keychainItem = KeychainPasswordItem(service: Consts.AuthKeychainServiceName, account: key)
                try keychainItem.deleteItem()
            } catch {
                printLog(.warning, text: "failed deleting auth token from keychain: \(error)")
                throw error
            }
        }
    }

    // MARK: - Error handling

    /**
     * Gets all available push providers for the current app.
     *
     * - returns: A task containing {@link AvailablePushProviders} that can be resolved on completion
     * of the request.
     */
    public func getPushProviders() -> StitchTask<AvailablePushProviders> {
        return self.performRequest(method: .get,
                                   endpoint: Consts.PushPath,
                                   isAuthenticatedRequest: false,
                                   responseType: AvailablePushProviders.self)
    }

    /**
     * Called when a user logs in with this client.
     */
    private func onLogin() {
        authDelegates.forEach { $0?.onLogin() }
    }

    /**
     * Called when a user is logged out from this client.
     */
    private func onLogout() {
        authDelegates.forEach { $0?.onLogout() }
    }

    /**
     Adds a delegate for auth events.
     
     - parameter delegate: The delegate that will receive auth events.
     */
    public func addAuthDelegate(delegate: AuthDelegate) {
        self.authDelegates.append(delegate)
    }
}
