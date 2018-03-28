import ExtendedJSON

open class CoreStitchService {
    private let requestClient: StitchAuthRequestClient
    private let serviceRoutes: StitchServiceRoutes
    private let serviceName: String

    public init(requestClient: StitchAuthRequestClient,
                routes: StitchServiceRoutes,
                name: String) {
        self.requestClient = requestClient
        self.serviceRoutes = routes
        self.serviceName = name
    }

    private final func callFunctionRequest(withName name: String,
                                           withArgs args: BSONArray) throws -> StitchAuthDocRequest {
        return try StitchAuthDocRequestBuilderImpl {
            
            $0.method = .post
            $0.path = self.serviceRoutes.functionCallRoute
            $0.document = [
                "name": name,
                "service": self.serviceName,
                "args": args
            ]
        }.build()
    }

    public func callFunctionInternal(withName name: String,
                                     withArgs args: BSONArray) throws -> Any {
        
        
        return try self.requestClient.doAuthenticatedJSONRequest(
            callFunctionRequest(withName: name, withArgs: args)
        )
    }
}
