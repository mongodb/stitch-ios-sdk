import XCTest
import MongoSwift
@testable import StitchCoreAWSService

final class AWSRequestUnitTests: XCTestCase {
    func testBuilder() throws {
        // Require at a minimum service and action
        XCTAssertThrowsError(try AWSRequestBuilder().build()) { error in
            XCTAssertTrue(error is AWSRequestBuilderError)
        }

        XCTAssertThrowsError(try AWSRequestBuilder().with(service: "ses").build()) { error in
            XCTAssertTrue(error is AWSRequestBuilderError)
        }

        XCTAssertThrowsError(try AWSRequestBuilder().with(action: "send").build()) { error in
            XCTAssertTrue(error is AWSRequestBuilderError)
        }

        // Minimum satisifed
        let expectedService = "ses"
        let expectedAction = "send"

        let request = try AWSRequestBuilder()
            .with(service: expectedService)
            .with(action: expectedAction)
            .build()

        XCTAssertEqual(expectedService, request.service)
        XCTAssertEqual(expectedAction, request.action)
        XCTAssertNil(request.region)
        XCTAssertEqual(0, request.arguments.count)

        // Full request
        let expectedRegion = "us-east-1"
        let expectedArgs: Document = ["hi": "hello"]

        let fullRequest = try AWSRequestBuilder()
            .with(service: expectedService)
            .with(action: expectedAction)
            .with(region: expectedRegion)
            .with(arguments: expectedArgs)
            .build()

        XCTAssertEqual(expectedService, fullRequest.service)
        XCTAssertEqual(expectedAction, fullRequest.action)
        XCTAssertEqual(expectedRegion, fullRequest.region)
        XCTAssertEqual(expectedArgs, fullRequest.arguments)
    }
}
