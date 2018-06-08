import Foundation

public class CoreRemoteMongoCursor<T: Codable>: Sequence, IteratorProtocol {
    private var documents: IndexingIterator<[T]>
    
    internal init(documents: IndexingIterator<[T]>) {
        self.documents = documents
    }
    
    /// Returns the next `Document` in this cursor, or nil if there are no documents remaining
    public func next() -> T? {
        return documents.next()
    }
}
