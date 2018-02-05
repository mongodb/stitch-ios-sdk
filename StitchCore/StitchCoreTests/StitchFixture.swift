import Foundation
import StitchCore
import PromiseKit
//import bson
//import mongoc
import ExtendedJson

private let defaultUri = "mongodb://localhost:26000/test"

private extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}

private func randomString(_ length: UInt32) -> String {
    let chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    return stride(from: length, to: 0, by: -1).reduce(into: "") { result, next in
        let index = chars.index(chars.startIndex, offsetBy: Int(arc4random_uniform(UInt32(chars.count))))
        result += String(chars[index])
    }
}

private let testSalt = "DQOWene1723baqD!_@#"

private func pbkdf2(hash: CCPBKDFAlgorithm, password: String, salt: Data, keyByteCount: Int, rounds: Int) -> Data? {
    let passwordData = password.data(using:String.Encoding.utf8)!
    var derivedKeyData = Data(repeating:0, count:keyByteCount)

    let derivationStatus = derivedKeyData.withUnsafeMutableBytes {derivedKeyBytes in
        salt.withUnsafeBytes { saltBytes in

            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                password, passwordData.count,
                saltBytes, salt.count,
                hash,
                UInt32(rounds),
                derivedKeyBytes, derivedKeyData.count)
        }
    }
    if (derivationStatus != 0) {
        print("Error: \(derivationStatus)")
        return nil;
    }

    return derivedKeyData
}

private func hashValue(withKey key: String, salt: Data) -> String? {
    return pbkdf2(hash: CCPBKDFAlgorithm(kCCPBKDF2),
                  password: key,
                  salt: salt,
                  keyByteCount: key.count,
                  rounds: 4096)?.hexEncodedString()
}

private struct User: Codable {
    struct Identity: Codable {
        let id: String
        let providerType: String
        let providerId: ObjectId
    }
    struct Role: Codable {
        let roleName: String
        let groupId: String
    }

    let userId: String
    let domainId: ObjectId
    let identities: [Identity]
    let roles: [Role]
}

private struct ApiKey: Codable {
    let _id: ObjectId
    let domainId: ObjectId
    let userId: String
    let appId: ObjectId
    let key: String
    let hashedKey: String
    let name: String
    let disabled: Bool
    let visible: Bool
}

private struct Group: Codable {
    let domainId: ObjectId
    let groupId: String
}

private typealias UserData = (user: User, apiKey: ApiKey, group: Group)

private func generateTestRootUser() throws -> UserData {
    let rootId = try ObjectId(hexString: "000000000000000000000000")
    let rootProviderId = try ObjectId(hexString: "000000000000000000000001")
    let apiKeyId = ObjectId()
    let userId = ObjectId().hexString
    let groupId = ObjectId().hexString
    let testUser = User.init(userId: ObjectId().hexString,
                             domainId: rootId,
                             identities: [User.Identity.init(id: apiKeyId.hexString, providerType: "api-key", providerId: rootProviderId)],
                             roles: [User.Role.init(roleName: "groupOwner", groupId: groupId)])

    let key = randomString(64)
    let hashedKey = hashValue(withKey: key, salt: testSalt.data(using: .utf8)!)

    let testAPIKey = ApiKey.init(_id: apiKeyId,
                                 domainId: rootId,
                                 userId: userId,
                                 appId: rootId,
                                 key: key,
                                 hashedKey: hashedKey!,
                                 name: apiKeyId.hexString,
                                 disabled: false,
                                 visible: true)

    let testGroup = Group.init(domainId: rootId, groupId: groupId)

    return (user: testUser, apiKey: testAPIKey, group: testGroup)
}

class StitchFixtureFactory {
    static func create(mongoUri: String = defaultUri, baseUrl: String = defaultServerUrl) -> Promise<StitchFixture> {
        let fixture = try! StitchFixture.init(mongoUri: mongoUri, baseUrl: baseUrl)
        return fixture.initPromise.flatMap { fixture }
    }
}

class StitchFixture {
    let mongoUri: String
    let baseUrl: String
    private let userData: UserData
    var admin: StitchAdminClient!

    fileprivate let initPromise: Promise<Void>

    fileprivate init(mongoUri: String = defaultUri, baseUrl: String = defaultServerUrl) throws {
        self.mongoUri = mongoUri
        self.baseUrl = baseUrl
        self.userData = try generateTestRootUser()

        
//        let authDb = try MongoKitten.Database("\(mongoUri)/auth")
//        if authDb.server.isConnected {
//            try authDb["users"].insert(Document.init(dictionaryLiteral: ("yo", 1)))
//            try authDb["users"].insert(Document.init(data: JSONEncoder().encode(self.userData.user)))
//            try authDb["apiKeys"].insert(Document.init(data: JSONEncoder().encode(self.userData.apiKey)))
//            try authDb["groups"].insert(Document.init(data: JSONEncoder().encode(self.userData.group)))
//        }
        self.initPromise = Promise()
        initPromise.then { StitchAdminClientFactory.create(baseUrl: self.baseUrl) }.done { self.admin = $0 }.cauterize()
    }

    func extractDataPoints() ->
        (apiKey: String, groupId: String, serverUrl: String) {
            return (userData.apiKey.key, userData.group.groupId, baseUrl)
    }
}
