import Foundation

public class CoreRemoteMongoCursor<T: Codable> : Sequence, IteratorProtocol {
    
    private var documents: IndexingIterator<[T]>
    
    init(documents: IndexingIterator<[T]>) {
        self.documents = documents
    }
    
    public func next() -> T? {
        return documents.next()
    }
}
