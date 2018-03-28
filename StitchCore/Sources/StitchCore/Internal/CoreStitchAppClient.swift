import ExtendedJSON

public final class CoreStitchAppClient {
    private let authRequestClient: StitchAuthRequestClient
    private let routes: StitchAppRoutes

    public init(authRequestClient: StitchAuthRequestClient, routes: StitchAppRoutes) {
        self.authRequestClient = authRequestClient
        self.routes = routes
    }

    private func callFunctionRequest(withName name: String,
                                     withArgs args: BSONArray) throws -> StitchAuthDocRequest {
        let route = self.routes.serviceRoutes.functionCallRoute
        return try StitchAuthDocRequestBuilderImpl {
            $0.method = .post
            $0.path = route
            $0.document = [
                "name": name,
                "args": args
            ]
        }.build()
    }

    public func callFunctionInternal(withName name: String,
                                     withArgs args: BSONArray) throws -> Any {
        return try self.authRequestClient.doAuthenticatedJSONRequest(
            callFunctionRequest(withName: name, withArgs: args)
        )
    }
}
