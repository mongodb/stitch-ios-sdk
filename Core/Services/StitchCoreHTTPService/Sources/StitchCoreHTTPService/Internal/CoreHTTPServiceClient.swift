import Foundation
import MongoSwift
import StitchCoreSDK

public final class CoreHTTPServiceClient {
    private let service: CoreStitchServiceClient
    
    public init(withService service: CoreStitchServiceClient) {
        self.service = service
    }
    
    public func execute(request: HTTPRequest,
                        timeout: TimeInterval? = nil) throws -> HTTPResponse {
        var args: Document = [ "url": request.url ]
        
        do {
            if let authURL = request.authURL {
                args["authUrl"] = authURL
            }
            
            if let headers = request.headers {
                args["headers"] = try BsonEncoder().encode(headers)
            }
            
            if let cookies = request.cookies {
                args["cookies"] = try BsonEncoder().encode(cookies)
            }
            
            if let body = request.body {
                args["body"] = Binary.init(data: body, subtype: .binary)
            }
            
            if let encodeBodyAsJSON = request.encodeBodyAsJSON {
                args["encodeBodyAsJSON"] = encodeBodyAsJSON
            }
            
            if let form = request.form {
                args["form"] = try BsonEncoder().encode(form)
            }
            
            if let followRedirects = request.followRedirects {
                args["followRedirects"] = followRedirects
            }
        } catch let error {
            if let stitchError = error as? StitchError {
                throw stitchError
            }
            
            throw StitchError.requestError(withError: error, withRequestErrorCode: .encodingError)
        }
        
        return try service.callFunction(
            withName: request.method.rawValue,
            withArgs: [args],
            withRequestTimeout: timeout
        )
    }
}
