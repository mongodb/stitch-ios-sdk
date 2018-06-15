import Foundation
import MongoSwift

open class CoreStitchPushClientImpl: CoreStitchPushClient {
    private let requestClient: StitchAuthRequestClient
    private let pushRoutes: StitchPushRoutes
    private let serviceName: String
    
    public init(requestClient: StitchAuthRequestClient,
                routes: StitchPushRoutes,
                serviceName: String) {
        self.requestClient = requestClient
        self.pushRoutes = routes
        self.serviceName = serviceName
    }
    
    public func registerInternal(withRegistrationInfo registrationInfo: Document) throws {
        let req = try StitchAuthDocRequestBuilder()
            .with(method: .put)
            .with(path: pushRoutes.registrationRoute(forServiceName: self.serviceName))
            .with(document: registrationInfo)
            .build()
        // Coerce the `Response` return type so response decoding is never attempted.
        let _: Response = try requestClient.doAuthenticatedRequest(req)
    }
    
    public func deregisterInternal() throws {
        let req = try StitchAuthRequestBuilder()
            .with(method: .delete)
            .with(path: pushRoutes.registrationRoute(forServiceName: self.serviceName))
            .build()
        // Coerce the `Response` return type so response decoding is never attempted.
        let _: Response = try requestClient.doAuthenticatedRequest(req)
    }
}
