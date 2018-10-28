import XCTest
import MongoSwift
import JWT
@testable import StitchCoreSDK

let apiAuthInfo = APIAuthInfoImpl.init(
    userID: "foo",
    deviceID: "bar",
    accessToken: "baz",
    refreshToken: "qux"
)

private let stitchUserProfile = StitchUserProfileImpl.init(
    userType: "grault",
    identities: [APIStitchUserIdentity.init(id: "garply",
                                            providerType: "waldo")],
    data: APIExtendedUserProfileImpl.init(name: "fred",
                                          email: "plugh",
                                          pictureURL: "thud",
                                          firstName: "wibble",
                                          lastName: "wobble",
                                          gender: "wubble",
                                          birthday: "flob",
                                          minAge: 42,
                                          maxAge: 84)
)

private let extendedAuthInfo = ExtendedAuthInfoImpl.init(loggedInProviderType: .anonymous,
                                                         loggedInProviderName: "corge",
                                                         userProfile: stitchUserProfile)

class StoreAuthInfoUnitTests: XCTestCase {
    private func assert(storeAuthInfo: StoreAuthInfo,
                        isEqualTo apiAuthInfo: APIAuthInfo) {
        XCTAssertEqual(storeAuthInfo.userID, apiAuthInfo.userID)
        XCTAssertEqual(storeAuthInfo.deviceID, apiAuthInfo.deviceID)
        XCTAssertEqual(storeAuthInfo.accessToken, apiAuthInfo.accessToken)
        XCTAssertEqual(storeAuthInfo.refreshToken, apiAuthInfo.refreshToken)
    }

    private func assert(storeAuthInfo: StoreAuthInfo,
                        isEqualTo extendedAuthInfo: ExtendedAuthInfo) {
        XCTAssertEqual(storeAuthInfo.loggedInProviderName, extendedAuthInfo.loggedInProviderName)
        XCTAssertEqual(storeAuthInfo.loggedInProviderType, extendedAuthInfo.loggedInProviderType)
    }

    private func assert(userProfile: StitchUserProfile,
                        isEqualTo otherUserProfile: StitchUserProfile) {
        XCTAssertEqual(userProfile.userType, otherUserProfile.userType)
        XCTAssertEqual(userProfile.identities.first!.id,
                       otherUserProfile.identities.first!.id)
        XCTAssertEqual(userProfile.identities.first!.providerType,
                       otherUserProfile.identities.first!.providerType)

        XCTAssertEqual(userProfile.name, otherUserProfile.name)
        XCTAssertEqual(userProfile.email, otherUserProfile.email)
        XCTAssertEqual(userProfile.pictureURL, otherUserProfile.pictureURL)
        XCTAssertEqual(userProfile.firstName, otherUserProfile.firstName)
        XCTAssertEqual(userProfile.lastName, otherUserProfile.lastName)
        XCTAssertEqual(userProfile.gender, otherUserProfile.gender)
        XCTAssertEqual(userProfile.birthday, otherUserProfile.birthday)
        XCTAssertEqual(userProfile.minAge, otherUserProfile.minAge)
        XCTAssertEqual(userProfile.maxAge, otherUserProfile.maxAge)
    }

    func testInit() throws {
        let storeAuthInfo = StoreAuthInfo.init(withAPIAuthInfo: apiAuthInfo,
                                               withExtendedAuthInfo: extendedAuthInfo)

        self.assert(storeAuthInfo: storeAuthInfo, isEqualTo: apiAuthInfo)
        self.assert(storeAuthInfo: storeAuthInfo, isEqualTo: extendedAuthInfo)
        self.assert(userProfile: storeAuthInfo.userProfile, isEqualTo: stitchUserProfile)
    }

    func testCodable() throws {
        let storeAuthInfo = StoreAuthInfo.init(withAPIAuthInfo: apiAuthInfo,
                                               withExtendedAuthInfo: extendedAuthInfo)

        let decodedAuthInfo = try JSONDecoder().decode(StoreAuthInfo.self,
                                                       from: JSONEncoder().encode(storeAuthInfo))

        self.assert(storeAuthInfo: storeAuthInfo, isEqualTo: decodedAuthInfo as APIAuthInfo)
        self.assert(storeAuthInfo: storeAuthInfo, isEqualTo: decodedAuthInfo as ExtendedAuthInfo)
        self.assert(userProfile: storeAuthInfo.userProfile, isEqualTo: decodedAuthInfo.userProfile)
    }

    func testWrite() throws {
        var storage: Storage = MemoryStorage()

        let storeAuthInfo = StoreAuthInfo.init(withAPIAuthInfo: apiAuthInfo,
                                               withExtendedAuthInfo: extendedAuthInfo)

        XCTAssertNoThrow(try storeAuthInfo.write(toStorage: &storage))

        let readAuthInfo = try StoreAuthInfo.read(fromStorage: storage)!

        self.assert(storeAuthInfo: storeAuthInfo, isEqualTo: readAuthInfo as APIAuthInfo)
        self.assert(storeAuthInfo: storeAuthInfo, isEqualTo: readAuthInfo as ExtendedAuthInfo)
        self.assert(userProfile: storeAuthInfo.userProfile, isEqualTo: readAuthInfo.userProfile)
    }
}
