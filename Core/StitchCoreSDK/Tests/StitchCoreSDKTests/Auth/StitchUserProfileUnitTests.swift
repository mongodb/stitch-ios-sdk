import XCTest
@testable import StitchCoreSDK
import MongoSwift

private let firstName = "firstName"
private let lastName = "lastName"
private let email = "email"
private let gender = "gender"
private let birthday = "birthday"
private let pictureURL = "pictureURL"
private let minAge = 42
private let maxAge = 84

class StitchUserProfileUnitTests: XCTestCase {
    private let anonUserData: Document = [
        "first_name": firstName,
        "last_name": lastName,
        "email": email,
        "gender": gender,
        "birthday": birthday,
        "picture_url": pictureURL,
        "min_age": minAge,
        "max_age": maxAge
    ]
    private let anonIdentityDoc: Document = [
        "id": ObjectId().description,
        "provider_type": "anon-user"
    ]

    func testStitchUserProfileImplInit() throws {
        let anonIdentity = try BsonDecoder().decode(APIStitchUserIdentity.self, from: anonIdentityDoc)
        let stitchUserProfileImpl = StitchUserProfileImpl.init(userType: "local-userpass",
                                                               identities: [anonIdentity],
                                                               data: APIExtendedUserProfileImpl.init())

        XCTAssertEqual(stitchUserProfileImpl.firstName, nil)
        XCTAssertEqual(stitchUserProfileImpl.lastName, nil)
        XCTAssertEqual(stitchUserProfileImpl.email, nil)
        XCTAssertEqual(stitchUserProfileImpl.gender, nil)
        XCTAssertEqual(stitchUserProfileImpl.birthday, nil)
        XCTAssertEqual(stitchUserProfileImpl.pictureURL, nil)
        XCTAssertEqual(stitchUserProfileImpl.minAge, nil)
        XCTAssertEqual(stitchUserProfileImpl.maxAge, nil)
        XCTAssertEqual(stitchUserProfileImpl.userType, "local-userpass")
        XCTAssertEqual(stitchUserProfileImpl.identities.count, 1)
        XCTAssert(stitchUserProfileImpl.identities.first! == anonIdentity)
    }
}
