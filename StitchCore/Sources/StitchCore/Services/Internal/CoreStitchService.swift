import MongoSwift
import Foundation

/**
 * A class providing the core functionality necessary to make authenticated function call requests for a particular
 * Stitch service.
 */
public protocol CoreStitchService {
    func callFunctionInternal(withName name: String, withArgs args: [BsonValue], withRequestTimeout requestTimeout: TimeInterval?) throws
    
    func callFunctionInternal<T: Codable>(withName name: String, withArgs args: [BsonValue], withRequestTimeout requestTimeout: TimeInterval?) throws -> T
}
