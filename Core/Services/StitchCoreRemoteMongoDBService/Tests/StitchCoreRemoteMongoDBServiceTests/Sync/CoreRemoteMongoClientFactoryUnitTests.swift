import XCTest
@testable import StitchCoreRemoteMongoDBService
import StitchCoreSDK
import StitchCoreSDKMocks
import StitchCoreLocalMongoDBService

class CoreRemoteMongoClientFactoryUnitTests: XCMongoMobileTestCase {
    func testClient() throws {
        let client1 = try CoreRemoteMongoClientFactory.shared.client(withService: mockServiceClient,
                                                                     withAppInfo: appClientInfo)
        let client2 = try CoreRemoteMongoClientFactory.shared.client(withService: mockServiceClient,
                                                                     withAppInfo: appClientInfo)

        XCTAssert(client1 === client2)
    }
}
