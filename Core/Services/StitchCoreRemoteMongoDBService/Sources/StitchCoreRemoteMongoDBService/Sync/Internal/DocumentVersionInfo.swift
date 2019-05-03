import MongoSwift

internal let documentVersionField = "__stitch_sync_version"

/**
 Returns a query filter for the given document _id and version. The version is allowed to be
 null. The query will match only if there is either no version on the document in the database
 in question if we have no reference of the version or if the version matches the database's
 version.

 - parameter documentId: the _id of the document.
 - parameter version: the expected version of the document, if any.
 - returns a query filter for the given document _id and version for a remote operation.
 */
private func getVersionedFilter(documentId: BSONValue?,
                                version: BSONValue?) -> Document {
    var filter: Document = ["_id": documentId ?? BSONNull()]
    if version == nil {
        filter[documentVersionField] = ["$exists": false] as Document
    } else {
        filter[documentVersionField] = version
    }
    return filter
}

public final class DocumentVersionInfo {
    let version: Version?
    let versionDoc: Document?
    /**
     Gets a filter that will only return the document in a query if
     it matches the current version. Will return null if a document
     id was not specified when the version info was constructed.
     */
    let filter: Document?
    /**
     Given a DocumentVersionInfo, returns a BSON document representing the next version. This means
     and incremented version count for a non-empty version, or a fresh version document for
     empty version.
     */
    lazy var nextVersion: Document = {
        guard let version = version,
            let versionDoc = versionDoc else {
            return DocumentVersionInfo.freshVersionDocument()
        }

        var nextVersion = versionDoc.mapValues({$0})
        nextVersion[Version.CodingKeys.versionCounter.rawValue] =
            version.versionCounter + 1
        return nextVersion
    }()

    /// The version information for a synchronized document.
    public struct Version: Codable {
        // swiftlint:disable nesting
        enum CodingKeys: String, CodingKey {
            case syncProtocolVersion = "spv"
            case instanceId = "id"
            case versionCounter = "v"
        }
        // swiftlint:enable nesting

        /// the synchronization protocol version of this version
        let syncProtocolVersion: Int
        /// the GUID instance id of this version
        let instanceId: String
        /// the version counter of this version
        let versionCounter: Int64
    }

    private init(version: Document?,
                 documentId: BSONValue?) throws {
        if let version = version {
            self.versionDoc = version
            self.version = try BSONDecoder().decode(Version.self,
                                                    from: version)
        } else {
            self.versionDoc = nil
            self.version = nil
        }

        if documentId != nil {
            self.filter = getVersionedFilter(documentId: documentId,
                                             version: version)
        } else {
            self.filter = nil
        }
    }

    /**
     Returns the current version info for a locally synchronized document.
     - parameter docConfig: the CoreDocumentSynchronizationConfig to get the version info from.
     - returns: a DocumentVersionInfo
     */
    static func getLocalVersionInfo(docConfig: CoreDocumentSynchronization) throws -> DocumentVersionInfo {
        return try DocumentVersionInfo(
            version: docConfig.lastKnownRemoteVersion,
            documentId: docConfig.documentId.value
        )
    }

    /**
     Returns the current version info for a provided remote document.
     - parameter remoteDocument the remote BSON document from which to extract version info
     - returns: a DocumentVersionInfo
     */
    static func getRemoteVersionInfo(remoteDocument: Document) throws -> DocumentVersionInfo? {
        guard let version = getDocumentVersionDoc(document: remoteDocument) else {
            return nil
        }
        return try DocumentVersionInfo(
            version: version,
            documentId: remoteDocument["_id"]
        )
    }

    /**
     Returns a DocumentVersionInfo constructed from a raw version document. The returned
     DocumentVersionInfo will have no document ID specified, so it will always return a null
     filter if the filter is requested.
     - parameter versionDoc the raw version document from which to extract version info
     - returns: a DocumentVersionInfo
     */
    static func fromVersionDoc(versionDoc: Document?) throws -> DocumentVersionInfo {
        return try DocumentVersionInfo(version: versionDoc, documentId: nil)
    }

    /**
     Returns a BSON version document representing a new version with a new instance ID, and
     version counter of zero.
     - returns: a BsonDocument representing a synchronization version
     */
    static func freshVersionDocument() -> Document {
        return [
            Version.CodingKeys.syncProtocolVersion.rawValue: 1,
            Version.CodingKeys.instanceId.rawValue: UUID().uuidString,
            Version.CodingKeys.versionCounter.rawValue: Int64(0)
        ]
    }

    /**
     Returns the version document of the given document, if any; returns null otherwise.
     - parameter document: the document to get the version from.
     - returns: the version of the given document, if any; returns null otherwise.
     */
    static func getDocumentVersionDoc(document: Document?) -> Document? {
        guard let document = document,
            document.hasKey(documentVersionField) else {
                return nil
        }
        return document[documentVersionField] as? Document
    }
}
