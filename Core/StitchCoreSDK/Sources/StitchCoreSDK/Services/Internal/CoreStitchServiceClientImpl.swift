import MongoSwift
import Foundation

open class CoreStitchServiceClientImpl: CoreStitchServiceClient {
    private let requestClient: StitchAuthRequestClient
    private let serviceRoutes: StitchServiceRoutes
    private let serviceName: String?
    
    public init(requestClient: StitchAuthRequestClient,
                routes:  StitchServiceRoutes,
                serviceName: String?) {
        self.requestClient = requestClient
        self.serviceRoutes = routes
        self.serviceName = serviceName
    }
    
    private func getCallServiceFunctionRequest(withName name: String,
                                               withArgs args: [BsonValue],
                                               withTimeout timeout: TimeInterval?) throws -> StitchAuthDocRequest {
        var body: Document = [
            "name": name,
            "arguments": args
        ]
        
        if let serviceName = serviceName {
            body["service"] = serviceName
        }
        
        let reqBuilder =
            StitchAuthDocRequestBuilder()
                .with(method: .post)
                .with(path: self.serviceRoutes.functionCallRoute)
                .with(document: body)
                
        if let timeout = timeout {
            reqBuilder.with(timeout: timeout)
        }
        
        return try reqBuilder.build()
    }
    
    public func callFunction(withName name: String,
                             withArgs args: [BsonValue],
                             withRequestTimeout timeout: TimeInterval? = nil) throws {
        // Coerce the `Response` return type so response decoding is not attempted.
        let _: Response = try requestClient.doAuthenticatedRequest(
            getCallServiceFunctionRequest(withName: name,
                                          withArgs: args,
                                          withTimeout: timeout))
    }
    
    public func callFunction<T: Decodable>(withName name: String,
                                           withArgs args: [BsonValue],
                                           withRequestTimeout timeout: TimeInterval? = nil) throws -> T {
        return try requestClient.doAuthenticatedRequest(
            getCallServiceFunctionRequest(withName: name,
                                          withArgs: args,
                                          withTimeout: timeout))
    }
}

