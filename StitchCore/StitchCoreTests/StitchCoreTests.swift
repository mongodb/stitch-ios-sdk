import XCTest
@testable import StitchCore
import ExtendedJson
import StitchLogger

class StitchCoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        LogManager.minimumLogLevel = .debug
    }

    override func tearDown() {
        super.tearDown()
    }

    let stitchClient = StitchClient(appId: "test-uybga")

    func testAuthInfoCodable() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." +
                "eyJleHAiOjE1MDg3Mjg0MDksImlhdCI6MTUwODcyN" +
                "jYwOSwiaXNzIjoiNTllZDU3NTE0ZmRkMWZhMWRhMzg1ODYyIiwic3RpdGNoX2RhdGEiOm51" +
                "bGwsInN0aXRjaF9kZXZJZCI6IjAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMCIsInN0aXRjaF9kb21haW" +
                "5JZCI6IjU5OTc0MTc5MDU4NDI5NTFkOGRiOThhNyIsInN1YiI6IjU5ZWQ1NzUxNGZkZDFm" +
                "YTFkYTM4NTg2MSIsInR5cCI6ImFjY2VzcyJ9.3P2uL5HSOBVUDxVEDSJIz3iMIPCCccSr-i9_gzNkoL8",
            "deviceId": "000000000000000000000000",
            "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." +
                "eyJleHAiOjE1MTM5MTA2MDksImlhdCI6MTUwODcyNjYwOSwic3" +
                "RpdGNoX2RhdGEiOm51bGwsInN0aXRjaF9kZXZJZCI6IjAwMDAwMDAwMDAwMDAwMDA" +
                "wMDAwMDAwMCIsInN0aXRjaF9kb21haW5JZCI6IjU5OTc0MTc5MDU4NDI5NT" +
                "FkOGRiOThhNyIsInN0aXRjaF9pZCI6IjU5ZWQ1NzUxNGZkZDFmYTFkYTM4NTg2MiIsInN0aXRjaF" +
                "9pZGVudCI6eyJpZCI6IjU5ZWQ1NzUxNGZkZDFmYTFkYTM4NTg2MC1jcWlnaXJkcGNldWx6am5hdG" +
                "xpdHlkZ3kiLCJwcm92aWRlcl90eXBlIjoiYW5vbi11c2VyIiwicHJvdmlkZXJfaWQiOiI1OTlkZ" +
                "jkwMjQ2MjI0YzFmMzllMzgyYjkifSwic3ViIjoiNTllZDU3NTE0ZmRkMWZhMWRhMzg1" +
                "ODYxIiwidHlwIjoicmVmcmVzaCJ9.mMVCk5Ygo29dfLYY4TrmiIuR-18iIX12guiWIcpmGnk",
            "userId": "59ed57514fdd1fa1da385861"
            ])
        XCTAssertNoThrow(try JSONDecoder().decode(AuthInfo.self, from: data))
    }
    
    func testIntegration() throws {
        let expectation = self.expectation(description: "fetch posts")

        stitchClient.anonymousAuth().response {
            switch $0.result {
            case .success: break
            case .failure(let error): XCTFail(error.localizedDescription)
            }
        }.then { _ -> StitchTask<BsonDocument> in
            return self.stitchClient.executePipeline(
                pipeline: Pipeline(action: "literal",
                                   args: ["items": [
                                        [ "type": "apples", "qty": 25 ] as BsonDocument,
                                        [ "type": "oranges", "qty": 50 ] as BsonDocument
                                    ] as BsonArray]))
        }.then { (doc: BsonDocument) in
            print(doc)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: TimeInterval(20))
    }
    // swiftlint:disable:next function_body_length
    func testAuthTokenExpirationCheck() {
        // access token with 5138-Nov-16
        let testUnexpiredAccessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
            ".eyJuYW1lIjoidGVzdC1hY2Nlc3MtdG9rZW4iLCJleHAiOjEwMDAwMDAwMDAwMH0" +
            ".KMAoJOX8Dh9wvt-XzrUN_W6fnypsPrlu4e-AOyqSAGw"

        // acesss token with 1970-Jan-01 expiration
        let testExpiredAccessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
            ".eyJuYW1lIjoidGVzdC1hY2Nlc3MtdG9rZW4iLCJleHAiOjF9.7tOdF0LXC_2iQMjNfZvQwwfLNiEj" +
            "-dd0VT0adP5bpjo"

        // access token where exp field is not a number
        let nanToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
            ".eyJuYW1lIjoidGVzdC1hY2Nlc3MtdG9rZW4iLCJleHAiOiJub3QgYSBudW1iZXIifQ.eeCE14Jd0Vh7WansvH4K2" +
            "-VgC0n-khz9aY8rlzfMGug"

        // access token without exp field
        let noExpToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
            ".eyJuYW1lIjoidGVzdC1hY2Nlc3MtdG9rZW4iLCJub3RfZXhwIjo1MDAwfQ" +
            ".0-T4a0ufpEMuwtZtJ-uDVCwuEgOf8ERY_ZWc3iKT3vo"

        // malformed access tokens
        let malformedToken1 = "blah.blah.blah"
        let malformedToken2 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoidGVzdC1hY2Nlc3MtdG9rZW4iLCJleHAiOjF9"

        var authObj: AuthInfo

        do {
            authObj = try JSONDecoder().decode(
                AuthInfo.self,
                from: JSONSerialization.data(withJSONObject: ["accessToken": testUnexpiredAccessToken,
                                                              "deviceId": "0",
                                                              "refreshToken": "0"]))
            XCTAssertFalse(authObj.isAccessTokenExpired()!)

            authObj = try JSONDecoder().decode(
                AuthInfo.self,
                from: JSONSerialization.data(withJSONObject: ["accessToken": testExpiredAccessToken,
                                                              "deviceId": "0",
                                                              "refreshToken": "0"]))
            XCTAssertTrue(authObj.isAccessTokenExpired()!)

            authObj = try JSONDecoder().decode(
                AuthInfo.self,
                from: JSONSerialization.data(withJSONObject: ["accessToken": nanToken,
                                                              "deviceId": "0",
                                                              "refreshToken": "0"]))
            XCTAssertNil(authObj.isAccessTokenExpired())

            authObj = try JSONDecoder().decode(
                AuthInfo.self,
                from: JSONSerialization.data(withJSONObject: ["accessToken": noExpToken,
                                                              "deviceId": "0",
                                                              "refreshToken": "0"]))
            XCTAssertNil(authObj.isAccessTokenExpired())

            XCTAssertThrowsError(try JSONDecoder().decode(
                AuthInfo.self,
                from: JSONSerialization.data(withJSONObject: ["accessToken": malformedToken1,
                                                              "deviceId": "0",
                                                              "refreshToken": "0"])))

            XCTAssertThrowsError(try JSONDecoder().decode(
                AuthInfo.self,
                from: JSONSerialization.data(withJSONObject: ["accessToken": malformedToken2,
                                                              "deviceId": "0",
                                                              "refreshToken": "0"])))
        } catch let error {
            XCTFail("Could not create Auth object to test token expiration check: \(error)")
        }
    }

}
