import Foundation
import MongoSwift

public protocol Collectible {
    associatedtype CollectionType
    
    func generateIdIfAbsentFromDocument(_ document: CollectionType) -> CollectionType
    
    func documentHasId(_ document: CollectionType) -> Bool
    
    func documentId(_ document: CollectionType) -> BsonValue
}
