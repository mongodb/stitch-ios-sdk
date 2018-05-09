import Foundation
import XCTest
import JWT
import StitchCore
import ExtendedJSON
@testable import StitchCore_iOS

class StitchAppClientIntegrationTests: StitchIntegrationTestCase {
    func testCallFunction() {
        _ = self.harness.addTestFunction()

        let exp1 = expectation(description: "logged in anonymously")
        let anonAuthClient = stitchAppClient.auth.providerClient(forProvider: AnonymousAuthProvider.clientSupplier)
        stitchAppClient.auth.login(withCredential: anonAuthClient.credential) { user, _ in
            XCTAssertNotNil(user)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let exp2 = expectation(description: "called function successfully")
        let randomInt = Int(arc4random())
        stitchAppClient.callFunction(withName: "testFunction", withArgs: [randomInt, "hello"]) { document, _ in
            XCTAssertNotNil(document)

            // STITCH-1345: when doAuthenticatedJSONRequest and `callFunction` returns a T: BSONCodable or
            // T: ExtendedJSONRepresentable, this test should be updated so the result need not be manually decoded
            guard let docMap = document as? [String: Any] else {
                XCTFail("Could not read document as map of string to Any")
                return
            }

            XCTAssertEqual(docMap["stringValue"] as? String, "hello")

            guard let intValue = docMap["intValue"] as? [String: Any] else {
                XCTFail("Int result missing in function return value")
                return
            }

            XCTAssertEqual(intValue["$numberLong"] as? String, String(randomInt))

            exp2.fulfill()
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "successfully errored out with a timeout when one was specified")
        stitchAppClient.callFunction(withName: "testFunction",
                                     withArgs: [randomInt, "hello"],
                                     withRequestTimeout: 0.00001) { _, error in
            let stitchError = error as? StitchError
            XCTAssertNotNil(error as? StitchError)
            if let err = stitchError {
                guard case .requestError(_, let errorCode) = err else {
                    XCTFail("callFunction returned an incorrect error type")
                    return
                }

                XCTAssertEqual(errorCode, .transportError)
            }
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)
    }
}
