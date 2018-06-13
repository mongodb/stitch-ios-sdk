import Foundation
import MongoSwift
import StitchCoreSDK

public class StitchAdminClient {
    private let adminAuth: StitchAdminAuth
    private let authRoutes: StitchAdminAuthRoutes

    public static let apiPath = "/api/admin/v3.0"
    public static let defaultServerURL = "http://localhost:9090"
    public static let defaultRequestTimeout: TimeInterval = 15.0

    public init?(baseURL: String = defaultServerURL,
                 transport: Transport = FoundationHTTPTransport.init(),
                 requestTimeout: TimeInterval = defaultRequestTimeout) {
        let requestClient = StitchRequestClientImpl.init(baseURL: baseURL,
                                                         transport: transport,
                                                         defaultRequestTimeout: requestTimeout)

        self.authRoutes = StitchAdminAuthRoutes.init()

        do {
            self.adminAuth = try StitchAdminAuth.init(
                requestClient: requestClient,
                authRoutes: self.authRoutes,
                storage: MemoryStorage.init()
            )
        } catch {
            return nil
        }
    }

    public func adminProfile() throws -> StitchAdminUserProfile {
        let req = try StitchAuthRequestBuilder()
            .with(method: .get)
            .with(path: authRoutes.profileRoute)
            .build()

        let response = try adminAuth.doAuthenticatedRequest(req)

        guard let responseBody = response.body else {
            throw StitchError.serviceError(withMessage: "empty response", withServiceErrorCode: .unknown)
        }

        return try JSONDecoder().decode(StitchAdminUserProfile.self, from: responseBody)
    }

    public func apps(withGroupID groupID: String) -> Apps {
        return Apps.init(adminAuth: adminAuth, url: "\(StitchAdminClient.apiPath)/groups/\(groupID)/apps")
    }

    public func loginWithCredential(credential: StitchCredential) throws -> StitchAdminUser {
        return try adminAuth.loginWithCredentialInternal(withCredential: credential)
    }

    public func logout() {
        return adminAuth.logoutInternal()
    }
}
