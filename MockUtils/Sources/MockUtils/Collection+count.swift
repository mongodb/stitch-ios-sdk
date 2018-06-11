import Foundation

public extension Collection {
    func count(where predicate: (Element) -> Bool) -> Int {
        var count: Int = 0
        self.forEach { element in
            if(predicate(element) == true) {
                count += 1
            }
        }
        return count
    }
}
