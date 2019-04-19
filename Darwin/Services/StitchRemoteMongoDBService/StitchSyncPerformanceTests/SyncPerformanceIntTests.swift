import XCTest
@testable import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

import Foundation

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
        try? CoreLocalMongoDBService.shared.initialize()
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        CoreLocalMongoDBService.shared.close()
    }
}

let harness = SyncPerformanceIntTestHarness()
let runId = ObjectId()

class SyncPerformanceIntTests: XCTestCase {
    let joiner = ThrowingCallbackJoiner()

    /*
     * Before: Perform remote insert of numDoc documents
     * Test: Configure sync to sync on the inserted docs and perform a sync pass
     * After: Ensure that the initial sync worked as expected
     */
    func testR2LOnlyInitialSync() {
        SyncR2LOnlyPerformanceTestDefinitions.testInitialSync(testHarness: harness, runId: runId)
    }

    /*
     * Before: Perform remote insert of numDoc documents, configure sync(), perform sync pass, disconnect networkMonitor
     * Test: Reconnect the network monitor and perform sync pass
     * After: Ensure that the sync pass worked as expected
     */
    func testR2LOnlyDisconnectReconnect() {
        SyncR2LOnlyPerformanceTestDefinitions.testDisconnectReconnect(testHarness: harness, runId: runId)
    }

    /*
     * Before: Perform remote insert of numDoc documents, configure sync(), perform sync pass
     *         Then remote update numChangeEvent documents remotely, and numConflict documents locally
     * Test: Perform sync pass
     * After: Ensure that the sync pass worked properly and that the local collection has received remote updates
     */
    func testR2LOnlySyncPass() {
        SyncR2LOnlyPerformanceTestDefinitions.testSyncPass(testHarness: harness, runId: runId)
    }
}
