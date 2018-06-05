import Foundation
import MongoSwift

/**
 * The response to an HTTP request over the HTTP service.
 */
public struct HttpResponse: Decodable {
    public enum CodingKeys: String, CodingKey {
        case status, statusCode, contentLength, headers, cookies, body
    }
    
    /**
     * The human readable status of the response.
     */
    public let status: String
    
    /**
     * The status code of the response.
     */
    public let statusCode: Int
    
    /**
     * The content length of the response.
     */
    public let contentLength: Int64
    
    /**
     * The response headers.
     */
    public let headers: [String: [String]]?
    
    /**
     * The response cookies.
     */
    public let cookies: [String: HttpCookie]?
    
    /**
     * The response body.
     */
    public let body: Data?
    
    internal init(status: String,
                  statusCode: Int,
                  contentLength: Int64,
                  headers: [String: [String]]?,
                  cookies: [String: HttpCookie],
                  body: Data?) {
        self.status = status
        self.statusCode = statusCode
        self.contentLength = contentLength
        self.headers = headers
        self.cookies = cookies
        self.body = body
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.status = try container.decode(String.self, forKey: .status)
        self.statusCode = try container.decode(Int.self, forKey: .statusCode)
        self.contentLength = try container.decode(Int64.self, forKey: .contentLength)
        self.headers = try container.decodeIfPresent([String: [String]].self, forKey: .headers)
        
        if let bsonBinaryBody = try container.decodeIfPresent(Binary.self, forKey: .body) {
            self.body = bsonBinaryBody.data
        } else {
            self.body = nil
        }
        
        if let decodedCookies = try container.decodeIfPresent(Document.self, forKey: .cookies) {
            var cookies: [String: HttpCookie] = [:]
            try decodedCookies.forEach { (key, bsonValue) in
                guard let document = bsonValue as? Document else {
                    throw MongoError.typeError(message: "unexpected cookie type in HTTP service response")
                }
                
                guard let value: String = try? document.get("value") else {
                    throw MongoError.typeError(message: "expected string value for cookie value in HTTP service response")
                }
                
                let keys = document.keys
                
                var path: String?
                if keys.contains(HttpCookie.CodingKeys.path.rawValue) {
                    path = try? document.get(HttpCookie.CodingKeys.path.rawValue)
                }
                
                var domain: String?
                if keys.contains(HttpCookie.CodingKeys.domain.rawValue) {
                    domain = try? document.get(HttpCookie.CodingKeys.domain.rawValue)
                }
                
                var expires: String?
                if keys.contains(HttpCookie.CodingKeys.expires.rawValue) {
                    expires = try? document.get(HttpCookie.CodingKeys.expires.rawValue)
                }
                
                var maxAge: String?
                if keys.contains(HttpCookie.CodingKeys.maxAge.rawValue) {
                    maxAge = try? document.get(HttpCookie.CodingKeys.maxAge.rawValue)
                }
                
                var secure: Bool?
                if keys.contains(HttpCookie.CodingKeys.secure.rawValue) {
                    secure = try? document.get(HttpCookie.CodingKeys.secure.rawValue)
                }
                
                var httpOnly: Bool?
                if keys.contains(HttpCookie.CodingKeys.httpOnly.rawValue) {
                    httpOnly = try? document.get(HttpCookie.CodingKeys.httpOnly.rawValue)
                }
                
                cookies[key] = HttpCookie.init(
                    name: key,
                    value: value,
                    path: path,
                    domain: domain,
                    expires: expires,
                    maxAge: maxAge,
                    secure: secure,
                    httpOnly: httpOnly
                )
            }
            
            self.cookies = cookies
        } else {
            self.cookies = nil
        }
    }
}
