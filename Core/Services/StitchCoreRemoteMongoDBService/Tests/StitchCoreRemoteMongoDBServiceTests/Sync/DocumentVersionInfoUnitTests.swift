import XCTest
import MongoMobile
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

class DocumentVersionInfoUnitTests: XCTestCase {
    func testVersionDocument() throws {
        var versionDocument = DocumentVersionInfo.freshVersionDocument()

        XCTAssertEqual(1,
                       versionDocument[DocumentVersionInfo.Version.CodingKeys.syncProtocolVersion.rawValue] as? Int)
        XCTAssertNotNil(versionDocument[DocumentVersionInfo.Version.CodingKeys.instanceId.rawValue])
        XCTAssertEqual(
            Int64(0),
            (versionDocument[DocumentVersionInfo.Version.CodingKeys.versionCounter.rawValue]
                as? BSONNumber)?.int64Value)

        let documentVersion = try DocumentVersionInfo.fromVersionDoc(versionDoc: versionDocument)

        XCTAssertTrue(documentVersion.version != nil)
        XCTAssertEqual(documentVersion.version?.syncProtocolVersion,
                       versionDocument[DocumentVersionInfo.Version.CodingKeys.syncProtocolVersion.rawValue] as? Int)
        XCTAssertEqual(documentVersion.version?.instanceId,
                       versionDocument[DocumentVersionInfo.Version.CodingKeys.instanceId.rawValue] as? String)
        XCTAssertEqual(documentVersion.version?.versionCounter,
                       (versionDocument[DocumentVersionInfo.Version.CodingKeys.versionCounter.rawValue] as? BSONNumber)?.int64Value)

        XCTAssertEqual(versionDocument, documentVersion.versionDoc)

        versionDocument = documentVersion.nextVersion

        XCTAssertEqual(1,
                       versionDocument[DocumentVersionInfo.Version.CodingKeys.syncProtocolVersion.rawValue] as? Int)
        XCTAssertNotNil(versionDocument[DocumentVersionInfo.Version.CodingKeys.instanceId.rawValue])
        XCTAssertEqual(1,
                       versionDocument[DocumentVersionInfo.Version.CodingKeys.versionCounter.rawValue] as? Int)
    }
}
