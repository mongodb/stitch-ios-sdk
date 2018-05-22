import Foundation
import BSON
import StitchCore

public class StitchAdminClient {
    private let adminAuth: StitchAdminAuth
    private let authRoutes: StitchAdminAuthRoutes

    public static let apiPath = "/api/admin/v3.0"
    public static let defaultServerUrl = "http://localhost:9090"
    public static let defaultRequestTimeout: TimeInterval = 15.0

    public init?(baseUrl: String = defaultServerUrl,
                 transport: Transport = FoundationHTTPTransport.init(),
                 requestTimeout: TimeInterval = defaultRequestTimeout) {
        let requestClient = StitchRequestClientImpl.init(baseURL: baseUrl,
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
        let req = try StitchAuthRequestBuilderImpl {
            $0.method = Method.get
            $0.path = authRoutes.profileRoute
        }.build()

        let response = try adminAuth.doAuthenticatedRequest(req)

        guard let responseBody = response.body else {
            throw StitchError.serviceError(withMessage: "empty response", withServiceErrorCode: .unknown)
        }

        return try JSONDecoder().decode(StitchAdminUserProfile.self, from: responseBody)
    }

    public func apps(withGroupId groupId: String) -> Apps {
        return Apps.init(adminAuth: adminAuth, url: "\(StitchAdminClient.apiPath)/groups/\(groupId)/apps")
    }

    public func loginWithCredential(credential: StitchCredential) throws -> StitchAdminUser {
        return try adminAuth.loginWithCredentialBlocking(withCredential: credential)
    }

    public func logout() {
        return adminAuth.logoutBlocking()
    }
}
