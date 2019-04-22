import XCTest
import MongoSwift
@testable import StitchCoreSDK

let apiAuthInfoExample = APIAuthInfoImpl.init(
    userID: "foo",
    deviceID: "bar",
    accessToken: "baz",
    refreshToken: "qux"
)

private let stitchUserProfileExample = StitchUserProfileImpl.init(
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
                                          minAge: "42",
                                          maxAge: "84")
)

private let authInfoExample1 = AuthInfo.init(
    userID: "oldID",
    deviceID: "oldDevice",
    accessToken: "oldAccessToken",
    refreshToken: "oldRefreshToken",
    loggedInProviderType: .anonymous,
    loggedInProviderName: "oldProviderName",
    userProfile: stitchUserProfileExample,
    lastAuthActivity: 10.0)
private let storeAuthInfoExample1 = StoreAuthInfo.init(withAuthInfo: authInfoExample1)

private let authInfoExample2 = AuthInfo.init(
    userID: "foo",
    deviceID: "bar",
    accessToken: "baz",
    refreshToken: "qux",
    loggedInProviderType: .anonymous,
    loggedInProviderName: "oldProviderName",
    userProfile: stitchUserProfileExample,
    lastAuthActivity: 10.0)
private let storeAuthInfoExample2 = StoreAuthInfo.init(withAuthInfo: authInfoExample2)

class StoreAuthInfoUnitTests: XCTestCase {
    private func assert(storeAuthInfo: StoreAuthInfo, isEqualTo authInfo: AuthInfo) {
        XCTAssertEqual(storeAuthInfo.userID, authInfo.userID)
        XCTAssertEqual(storeAuthInfo.deviceID, authInfo.deviceID)
        XCTAssertEqual(storeAuthInfo.loggedInProviderType, authInfo.loggedInProviderType)
        XCTAssertEqual(storeAuthInfo.loggedInProviderName, authInfo.loggedInProviderName)
        XCTAssertEqual(storeAuthInfo.refreshToken, authInfo.refreshToken)
        XCTAssertEqual(storeAuthInfo.accessToken, authInfo.accessToken)
        XCTAssertEqual(storeAuthInfo.lastAuthActivity, authInfo.lastAuthActivity)
        assert(userProfile: storeAuthInfo.userProfile, isEqualTo: authInfo.userProfile)
    }

    private func assert(oldAuthInfo: AuthInfo, isEqualTo authInfo: AuthInfo) {
        XCTAssertEqual(oldAuthInfo.userID, authInfo.userID)
        XCTAssertEqual(oldAuthInfo.deviceID, authInfo.deviceID)
        XCTAssertEqual(oldAuthInfo.loggedInProviderType, authInfo.loggedInProviderType)
        XCTAssertEqual(oldAuthInfo.loggedInProviderName, authInfo.loggedInProviderName)
        XCTAssertEqual(oldAuthInfo.refreshToken, authInfo.refreshToken)
        XCTAssertEqual(oldAuthInfo.accessToken, authInfo.accessToken)
        XCTAssertEqual(oldAuthInfo.lastAuthActivity, authInfo.lastAuthActivity)
        assert(userProfile: oldAuthInfo.userProfile, isEqualTo: authInfo.userProfile)
    }

    private func assert(userProfile: StitchUserProfile?, isEqualTo otherUserProfile: StitchUserProfile?) {
        guard let userProf = userProfile, let otherUserProf = otherUserProfile else {
            XCTAssertNil(userProfile)
            XCTAssertNil(otherUserProfile)
            return
        }
        XCTAssertEqual(userProf.userType, otherUserProf.userType)
        XCTAssertEqual(userProf.identities.first!.id,
                       otherUserProf.identities.first!.id)
        XCTAssertEqual(userProf.identities.first!.providerType,
                       otherUserProf.identities.first!.providerType)
        XCTAssertEqual(userProf.name, otherUserProf.name)
        XCTAssertEqual(userProf.email, otherUserProf.email)
        XCTAssertEqual(userProf.pictureURL, otherUserProf.pictureURL)
        XCTAssertEqual(userProf.firstName, otherUserProf.firstName)
        XCTAssertEqual(userProf.lastName, otherUserProf.lastName)
        XCTAssertEqual(userProf.gender, otherUserProf.gender)
        XCTAssertEqual(userProf.birthday, otherUserProf.birthday)
        XCTAssertEqual(userProf.minAge, otherUserProf.minAge)
        XCTAssertEqual(userProf.maxAge, otherUserProf.maxAge)
    }

    func testInit() throws {
        assert(storeAuthInfo: storeAuthInfoExample1, isEqualTo: authInfoExample1)
        assert(storeAuthInfo: storeAuthInfoExample2, isEqualTo: authInfoExample2)

        let apiAuthInfo = AuthInfo.init(
            userID: apiAuthInfoExample.userID,
            deviceID: apiAuthInfoExample.deviceID,
            accessToken: apiAuthInfoExample.accessToken,
            refreshToken: apiAuthInfoExample.refreshToken)
        let mergedAuthInfo = authInfoExample1.update(withNewAuthInfo: apiAuthInfo)
        assert(oldAuthInfo: mergedAuthInfo, isEqualTo: authInfoExample2)

        let newAuthInfo = mergedAuthInfo.withNewAuthActivity
        XCTAssertGreaterThan(newAuthInfo.lastAuthActivity ?? 0, 10)

        let loggedOutAuthInfo = mergedAuthInfo.loggedOut
        XCTAssertNil(loggedOutAuthInfo.accessToken)
        XCTAssertNil(loggedOutAuthInfo.refreshToken)
        XCTAssertFalse(loggedOutAuthInfo.isLoggedIn)

        let emptiedAuthInfo = mergedAuthInfo.emptiedOut
        XCTAssertNil(emptiedAuthInfo.userID)
        XCTAssertEqual(emptiedAuthInfo.deviceID, apiAuthInfoExample.deviceID)
    }

    func testCodable() throws {
        let storeAuthInfo = StoreAuthInfo.init(withAuthInfo: authInfoExample1)
        let decodedAuthInfo = try JSONDecoder().decode(StoreAuthInfo.self,
                                                       from: JSONEncoder().encode(storeAuthInfo))

        assert(storeAuthInfo: decodedAuthInfo, isEqualTo: authInfoExample1)
    }
}
