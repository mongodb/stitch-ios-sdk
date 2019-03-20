import Foundation

protocol Closable: AnyObject {
    func close()
}

class AnyClosable: Closable {
    private let closable: Closable

    init(_ closable: Closable) {
        self.closable = closable
    }

    func close() {
        self.closable.close()
    }
}
