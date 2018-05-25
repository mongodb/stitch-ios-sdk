import MongoSwift
import Foundation

open class CoreStitchServiceImpl: CoreStitchService {
    private let requestClient: StitchAuthRequestClient
    private let serviceRoutes: StitchServiceRoutes
    private let serviceName: String
    
    public init(requestClient: StitchAuthRequestClient,
                routes:  StitchServiceRoutes,
                name: String) {
        self.requestClient = requestClient
        self.serviceRoutes = routes
        self.serviceName = name
    }
    
    private func getCallServiceFunctionRequest(withName name: String,
                                               withArgs args: [BsonValue],
                                               withTimeout timeout: TimeInterval?) throws -> StitchAuthDocRequest {
        let body: Document = [
            "name": name,
            "service": serviceName,
            "arguments": args
        ]
        
        let reqBuilder = StitchAuthDocRequestBuilderImpl {
            $0.method = .post
            $0.path = self.serviceRoutes.functionCallRoute
            $0.document = body
            $0.body = body.canonicalExtendedJSON.data(using: .utf8)
            $0.timeout = timeout
        }
        
        return try reqBuilder.build()
    }
    
    public func callFunctionInternal(withName name: String, withArgs args: [BsonValue], withRequestTimeout timeout: TimeInterval? = nil) throws {
        let _: Response = try requestClient.doAuthenticatedRequest(getCallServiceFunctionRequest(withName: name,
                                                                                   withArgs: args,
                                                                                   withTimeout: timeout))
    }
    
    public func callFunctionInternal<T: Decodable>(withName name: String, withArgs args: [BsonValue], withRequestTimeout timeout: TimeInterval? = nil) throws -> T {
        return try requestClient.doAuthenticatedRequest(getCallServiceFunctionRequest(withName: name,
                                                                                      withArgs: args,
                                                                                      withTimeout: timeout))
    }
}

