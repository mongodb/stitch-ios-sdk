import Foundation
import XCTest
import MongoMobile
import MongoSwift


class XCMongoMobileConfiguration: NSObject, XCTestObservation {
    // This init is called first thing as the test bundle starts up and before any test
    // initialization happens
    override init() {
        super.init()
        // We don't need to do any real work, other than register for callbacks
        // when the test suite progresses.
        // XCTestObservation keeps a strong reference to observers
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testBundleWillStart(_ testBundle: Bundle) {
        try? MongoMobile.initialize()
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        try? MongoMobile.close()
    }
}


class XCMongoMobileTestCase: XCTestCase {
    static var client: MongoClient!

    override class func setUp() {
        let path = "\(FileManager().currentDirectoryPath)/path/local_mongodb/0/"
        var isDir : ObjCBool = true
        if !FileManager().fileExists(atPath: path, isDirectory: &isDir) {
            try! FileManager().createDirectory(atPath: path, withIntermediateDirectories: true)
        }

        let settings = MongoClientSettings(dbPath: path)
        client = try! MongoMobile.create(settings)
    }
}
