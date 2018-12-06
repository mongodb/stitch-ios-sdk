import MongoSwift
import Foundation

private let nameField = "name"
private let serviceField = "service"
private let argumentsField = "arguments"

private let stitchRequestField = "?stitch_request="

open class CoreStitchServiceClientImpl: CoreStitchServiceClient {
    private let requestClient: StitchAuthRequestClient
    private let serviceRoutes: StitchServiceRoutes
    public let serviceName: String?
    
    public init(requestClient: StitchAuthRequestClient,
                routes:  StitchServiceRoutes,
                serviceName: String?) {
        self.requestClient = requestClient
        self.serviceRoutes = routes
        self.serviceName = serviceName
    }
    
    private func getCallServiceFunctionRequest(withName name: String,
                                               withArgs args: [BSONValue],
                                               withTimeout timeout: TimeInterval?) throws -> StitchAuthDocRequest {
        var body: Document = [
            "name": name,
            "arguments": args
        ]
        
        if let serviceName = self.serviceName {
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

    private func getStreamServiceFunctionRequest(
        name: String,
        args: [BSONValue]) throws -> StitchAuthRequest {
        var body = [
            "name": name,
            "arguments": args
        ] as Document

        if let serviceName = self.serviceName {
            body["service"] = serviceName
        }

        let reqBuilder =
            StitchAuthRequestBuilder()
                .with(method: .get)
                .with(path: self.serviceRoutes.functionCallRoute +
                    stitchRequestField +
                    body.extendedJSON.data(using: .utf8)!.base64EncodedString())

        return try reqBuilder.build()
    }

    public func callFunction(withName name: String,
                             withArgs args: [BSONValue],
                             withRequestTimeout timeout: TimeInterval? = nil) throws {
        // Coerce the `Response` return type so response decoding is not attempted.
        let _: Response = try requestClient.doAuthenticatedRequest(
            getCallServiceFunctionRequest(withName: name,
                                          withArgs: args,
                                          withTimeout: timeout))
    }
    
    public func callFunction<T: Decodable>(withName name: String,
                                           withArgs args: [BSONValue],
                                           withRequestTimeout timeout: TimeInterval? = nil) throws -> T {
        return try requestClient.doAuthenticatedRequest(
            getCallServiceFunctionRequest(withName: name,
                                          withArgs: args,
                                          withTimeout: timeout))
    }

    public func streamFunction<T>(withName name: String,
                                  withArgs args: [BSONValue]) throws -> SSEStream<T> where T : Decodable {
        return try requestClient.openAuthenticatedStream(
            getStreamServiceFunctionRequest(name: name, args: args)
        )
    }
}

