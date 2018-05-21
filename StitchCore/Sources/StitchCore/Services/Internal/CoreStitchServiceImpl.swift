import BSON

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
                                               withArgs args: [BsonValue]) throws -> StitchAuthDocRequest {
        let body: Document = [
            "name": name,
            "service": serviceName,
            "arguments": args
        ]
        
        let reqBuilder = StitchAuthDocRequestBuilderImpl {
            $0.method = .post
            $0.path = self.serviceRoutes.functionCallRoute
            $0.document = body
        }
        
        return try reqBuilder.build()
    }
    
    public func callFunctionInternal(withName name: String, withArgs args: [BsonValue]) throws {
        let _ = try requestClient.doAuthenticatedRequest(getCallServiceFunctionRequest(withName: name,
                                                                                       withArgs: args))
    }
    
    public func callFunctionInternal<T: Codable>(withName name: String, withArgs args: [BsonValue]) throws -> T {
        return try requestClient.doAuthenticatedJSONRequest(getCallServiceFunctionRequest(withName: name,
                                                                                          withArgs: args))
    }
}

