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

    // Tests for L2R-only scenarios
    /*
     * Before: Perform local insert of numDoc documents
     * Test: Configure sync to sync on the inserted docs and perform a sync pass
     * After: Ensure that the initial sync worked as expected
     */
    func testL2ROnlyInitialSync() {
        SyncL2ROnlyPerformanceTestDefinitions.testInitialSync(testHarness: harness, runId: runId)
    }

    /*
     * Before: Perform local insert of numDoc documents, configure sync(),
     *              perform sync pass, disconnect networkMonitor
     * Test: Reconnect the network monitor and perform sync pass
     * After: Ensure that the sync pass worked as expected
     */
    func testL2ROnlyDisconnectReconnect() {
        SyncL2ROnlyPerformanceTestDefinitions.testDisconnectReconnect(testHarness: harness, runId: runId)
    }

    /*
     * Before: Perform local insert of numDoc documents, configure sync(), perform sync pass
     *              perform local update for numChangeEvent documents
     * Test: Perform sync pass
     * After: Ensure that the sync pass worked properly
     */
    func testL2ROnlySyncPass() {
        SyncL2ROnlyPerformanceTestDefinitions.testSyncPass(testHarness: harness, runId: runId)
    }

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

    // Tests for Mixed R2L-L2R Scenarios

    /*
     * Before: Perform remote insert of numDoc / 2 documents
     *         Perform a local insert of numDoc / 2 documents
     *         Ensure there are numConflict conflicts
     * Test: Configure sync to sync on the inserted docs and perform a sync pass
     * After: Ensure that the initial sync worked as expected
     */
    func testMixedInitialSync() {
        SyncMixedPerformanceTestDefinitions.testInitialSync(testHarness: harness, runId: runId)
    }

    /*
     * Before: Perform remote insert of numDoc / 2 documents
     *         Perform a local insert of numDoc / 2 documents
     *         Configure sync(), perform sync pass, disconnect networkMonitor
     *         Ensure sync worked properly
     * Test: Reconnect the network monitor and perform sync pass
     * After: Ensure that the sync pass worked as expected
     */
    func testMixedDisconnectReconnect() {
        SyncMixedPerformanceTestDefinitions.testDisconnectReconnect(testHarness: harness, runId: runId)
    }

    /*
     * Before: Perform remote insert of numDoc / 2 documents
     *         Perform a local insert of numDoc / 2 documents
     *         Configure sync(), perform sync pass
     *         Update numChangeEvents / 2 documents remotely
     *         Update numChangeEvents / 2 documents locally
     *              Where numConflicts docs are updates on the same documents
     * Test: Perform sync pass
     * After: Ensure that the sync pass worked properly
     */
    func testMixedOnlySyncPass() {
        SyncMixedPerformanceTestDefinitions.testSyncPass(testHarness: harness, runId: runId)
    }
}
