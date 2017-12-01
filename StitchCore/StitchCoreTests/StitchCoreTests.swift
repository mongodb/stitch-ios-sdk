import XCTest
@testable import StitchCore
import ExtendedJson
import StitchLogger
import MongoDBService

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

    func testMongo() {
        let expectation = self.expectation(description: "execute mongo funcs")

        let collection = MongoDBClient(stitchClient: stitchClient,
                                       serviceName: "mongodb-atlas")
            .database(named: "todo").collection(named: "items")

        stitchClient.anonymousAuth().then { (_: String) -> StitchTask<Int> in
            return collection.count(query: Document())
        }.then { (_: Int) -> StitchTask<ObjectId> in
            return collection.insertOne(document: ["bill": "jones",
                                                   "owner_id": self.stitchClient.auth?.userId ?? "0"])
        }.then { (_: ObjectId) -> StitchTask<Int> in
            return collection.count(query: [:])
        }.then { (count: Int) -> StitchTask<[ObjectId]> in
            XCTAssert(count == 1)
            return collection.insertMany(documents: [["bill": "jones",
                                                     "owner_id": self.stitchClient.auth?.userId ?? "0"],
                                                     ["bill": "jones",
                                                      "owner_id": self.stitchClient.auth?.userId ?? "0"]])
        }.then { (_: [ObjectId]) -> StitchTask<[Document]> in
            return collection.find(query: ["owner_id": self.stitchClient.auth?.userId ?? "0"], limit: 10)
        }.then { (coll: [Document]) -> StitchTask<Document> in
            XCTAssert(coll.count == 3)
            return collection.updateOne(query: ["owner_id": self.stitchClient.auth?.userId ?? "0"],
                                        update: ["owner_id": self.stitchClient.auth?.userId ?? "0",
                                                 "bill": "thompson"])
        }.then { (result: Document) -> StitchTask<Document> in
            XCTAssertEqual(result["matchedCount"] as? Int32, 1)
            return collection.updateMany(query: ["owner_id": self.stitchClient.auth?.userId ?? "0"],
                                        update: ["owner_id": self.stitchClient.auth?.userId ?? "0",
                                                 "bill": "jackson"])
        }.then { (result: Document) -> StitchTask<Document> in
            XCTAssertEqual(result["matchedCount"] as? Int32, 3)
            return collection.deleteOne(query: ["owner_id": self.stitchClient.auth?.userId ?? "0"])
        }.then { (result: Document) -> StitchTask<Document> in
            XCTAssert(result["deletedCount"] as? Int32 == 1)
            return collection.deleteMany(query: ["owner_id": self.stitchClient.auth?.userId ?? "0"])
        }.then { (result: Document) -> Void in
            XCTAssert(result["deletedCount"] as? Int32 == 2)
            expectation.fulfill()
        }.catch { err in
            XCTFail(err.localizedDescription)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 20, handler: nil)
    }

    func testIntegration() throws {
        let expectation = self.expectation(description: "execute various requests")

        stitchClient.fetchAuthProviders().then { (auths: AuthProviderInfo) -> Void in
            XCTAssertNotNil(auths.anonymousAuthProviderInfo)
            XCTAssertNotNil(auths.emailPasswordAuthProviderInfo)
            XCTAssertNotNil(auths.googleProviderInfo)
            XCTAssertNil(auths.facebookProviderInfo)

            XCTAssert(auths.googleProviderInfo?.config.clientId ==
            "405021717222-8n19u6ij79kheu4lsaeekfh9b1dng7b7.apps.googleusercontent.com")
            XCTAssert(auths.googleProviderInfo?.metadataFields?.contains {$0.name == "profile"} ?? false)
            XCTAssert(auths.googleProviderInfo?.metadataFields?.contains {$0.name == "email"} ?? false)
        }.then { _ -> StitchTask<String> in
            return self.stitchClient.login(withProvider: EmailPasswordAuthProvider(username: "stitch@mongodb.com",
                                                                                    password: "stitchuser"))
        }.then { (userId: String) -> StitchTask<[ApiKey]> in
            XCTAssert(userId == "59ee23094fdd1fa1da3d1057")
            return self.stitchClient.auth!.fetchApiKeys()
        }.then { (keys: [ApiKey]) -> StitchTask<Void> in
            let task = StitchTask<Void>()
            if !keys.isEmpty {
                var counter = 0
                keys.forEach {
                    self.stitchClient.auth!.deleteApiKey(id: $0.id).then {
                        counter += 1
                        if counter == keys.count {
                            task.result = .success(Void())
                        }
                    }.catch { err in
                        task.result = .failure(err)
                    }
                }
            } else {
                task.result = .success(Void())
            }
            return task
        }.then { _ -> StitchTask<ApiKey> in
            return self.stitchClient.auth!.createApiKey(name: "test4")
        }.then { _ -> StitchTask<[ApiKey]> in
            return self.stitchClient.auth!.fetchApiKeys()
        }.then { (keys: [ApiKey]) -> StitchTask<ApiKey> in
            return self.stitchClient.auth!.fetchApiKey(id: keys.first { $0.name == "test4"}!.id)
        }.then { (key: ApiKey) -> StitchTask<Void> in
            return self.stitchClient.auth!.disableApiKey(id: key.id)
        }.then { _ -> StitchTask<[ApiKey]> in
            return self.stitchClient.auth!.fetchApiKeys()
        }.then { (keys: [ApiKey]) -> StitchTask<Void> in
            XCTAssert(keys.first { $0.name == "test4"}!.disabled)
            return self.stitchClient.auth!.enableApiKey(id: keys.first { $0.name == "test4"}!.id)
        }.then { _ -> StitchTask<[ApiKey]> in
            return self.stitchClient.auth!.fetchApiKeys()
        }.then { (keys: [ApiKey]) -> StitchTask<Void> in
            XCTAssert(!keys[0].disabled)
            return self.stitchClient.auth!.deleteApiKey(id: keys.first { $0.name == "test4"}!.id)
        }.then { _ -> StitchTask<[ApiKey]> in
            return self.stitchClient.auth!.fetchApiKeys()
        }.then { (keys: [ApiKey]) in
            XCTAssert(keys.isEmpty)
            expectation.fulfill()
        }.catch { error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: TimeInterval(60))
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
                                                              "refreshToken": "0",
                                                              "userId": "0"]))
            XCTAssertFalse(authObj.isAccessTokenExpired()!)

            authObj = try JSONDecoder().decode(
                AuthInfo.self,
                from: JSONSerialization.data(withJSONObject: ["accessToken": testExpiredAccessToken,
                                                              "deviceId": "0",
                                                              "refreshToken": "0",
                                                              "userId": "0"]))
            XCTAssertTrue(authObj.isAccessTokenExpired()!)

            authObj = try JSONDecoder().decode(
                AuthInfo.self,
                from: JSONSerialization.data(withJSONObject: ["accessToken": nanToken,
                                                              "deviceId": "0",
                                                              "refreshToken": "0",
                                                              "userId": "0"]))
            XCTAssertNil(authObj.isAccessTokenExpired())

            authObj = try JSONDecoder().decode(
                AuthInfo.self,
                from: JSONSerialization.data(withJSONObject: ["accessToken": noExpToken,
                                                              "deviceId": "0",
                                                              "refreshToken": "0",
                                                              "userId": "0"]))
            XCTAssertNil(authObj.isAccessTokenExpired())

            XCTAssertThrowsError(try JSONDecoder().decode(
                AuthInfo.self,
                from: JSONSerialization.data(withJSONObject: ["accessToken": malformedToken1,
                                                              "deviceId": "0",
                                                              "refreshToken": "0",
                                                              "userId": "0"])))

            XCTAssertThrowsError(try JSONDecoder().decode(
                AuthInfo.self,
                from: JSONSerialization.data(withJSONObject: ["accessToken": malformedToken2,
                                                              "deviceId": "0",
                                                              "refreshToken": "0",
                                                              "userId": "0"])))
        } catch let error {
            XCTFail("Could not create Auth object to test token expiration check: \(error)")
        }
    }

}
