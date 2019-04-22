import MongoSwift
import Foundation

private let nameField = "name"
private let serviceField = "service"
private let argumentsField = "arguments"

private let stitchRequestQueryParam = "?stitch_request="

open class CoreStitchServiceClientImpl: CoreStitchServiceClient {
    private let requestClient: StitchAuthRequestClient
    private let serviceRoutes: StitchServiceRoutes
    private var serviceBinders: [AnyStitchServiceBinder]

    public let serviceName: String?

    public init(requestClient: StitchAuthRequestClient,
                routes: StitchServiceRoutes,
                serviceName: String?) {
        self.requestClient = requestClient
        self.serviceRoutes = routes
        self.serviceName = serviceName
        self.serviceBinders = []
    }

    private func getCallServiceFunctionRequest(withName name: String,
                                               withArgs args: [BSONValue],
                                               withTimeout timeout: TimeInterval?) throws -> StitchAuthDocRequest {
        var body: Document = [
            nameField: name,
            argumentsField: args
        ]

        if let serviceName = self.serviceName {
            body[serviceField] = serviceName
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
            nameField: name,
            argumentsField: args
        ] as Document

        if let serviceName = self.serviceName {
            body[serviceField] = serviceName
        }

        let reqBuilder =
            StitchAuthRequestBuilder()
                .with(method: .get)
                .with(path: self.serviceRoutes.functionCallRoute +
                    stitchRequestQueryParam +
                    body.canonicalExtendedJSON.data(using: .utf8)!.base64EncodedString())

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

    public func callFunctionOptionalResult<T: Decodable>(withName name: String,
                                                         withArgs args: [BSONValue],
                                                         withRequestTimeout timeout: TimeInterval? = nil) throws -> T? {
        return try requestClient.doAuthenticatedRequestOptionalResult(
            getCallServiceFunctionRequest(withName: name,
                                          withArgs: args,
                                          withTimeout: timeout))
    }

    public func streamFunction(withName name: String,
                               withArgs args: [BSONValue],
                               delegate: SSEStreamDelegate? = nil) throws -> RawSSEStream {
        return try requestClient.openAuthenticatedStream(
            getStreamServiceFunctionRequest(name: name, args: args), delegate: delegate
        )
    }

    public func bind(binder: StitchServiceBinder) {
        self.serviceBinders.append(AnyStitchServiceBinder(binder))
    }

    public func onRebindEvent(_ rebindEvent: RebindEvent) {
        for (index, element) in self.serviceBinders.enumerated() {
            guard let binder = element.reference else {
                self.serviceBinders.remove(at: index)
                continue
            }

            binder.onRebindEvent(rebindEvent)
        }
    }
}
