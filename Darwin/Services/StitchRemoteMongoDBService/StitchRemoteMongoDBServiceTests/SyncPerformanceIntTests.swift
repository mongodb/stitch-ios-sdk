//
//  SyncPerformanceIntTests.swift
//  StitchRemoteMongoDBServiceTests
//
//  Created by Tyler Kaye on 3/29/19.
//  Copyright © 2019 MongoDB. All rights reserved.
//
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

class SyncPerformanceIntTests: BaseStitchIntTestCocoaTouch {
    let harness = SyncPerformanceIntTestHarness()
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
//        ctx.teardown()
//        CoreLocalMongoDBService.shared.localInstances.forEach { client in
//            try! client.listDatabases().forEach {
//                try? client.db($0["name"] as! String).drop()
//            }
//        }
    }

    func testInitialSync2() {
        let testParam = TestParams(testName: "initialSync",
                                   runId: ObjectId(),
                                   numIters: 3,
                                   numDocs: [50],
                                   docSizes: [100])
        harness.runPerformanceTestWithParameters(testParams: testParam, testDefinition: {numDoc, docSize in

            print("My function")
            print("Test: \(numDoc) docs of size \(docSize)")
            sleep(3)
        }, customSetup: nil, customTeardown: nil)
    }
}
