import MongoSwift

internal let DOCUMENT_VERSION_FIELD = "__stitch_sync_version"
/**
 * Returns a query filter for the given document _id and version. The version is allowed to be
 * null. The query will match only if there is either no version on the document in the database
 * in question if we have no reference of the version or if the version matches the database's
 * version.
 *
 * - parameter documentId: the _id of the document.
 * - parameter version: the expected version of the document, if any.
 * - returns a query filter for the given document _id and version for a remote operation.
 */
private func getVersionedFilter(documentId: BSONValue?,
                                version: BSONValue?) -> Document {
    var filter: Document = ["_id": documentId]
    if version == nil {
        filter[DOCUMENT_VERSION_FIELD] = ["$exists": false] as Document
    } else {
        filter[DOCUMENT_VERSION_FIELD] = version
    }
    return filter
}

final class DocumentVersionInfo {
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
        guard hasVersion,
            let versionDoc = versionDoc,
            let version = version else {
                return DocumentVersionInfo.getFreshVersionDocument()
        }

        var nextVersion = versionDoc.mapValues({$0})
        nextVersion[Version.CodingKeys.versionCounter.rawValue] =
            version.versionCounter + 1
        return nextVersion
    }()
    /**
     * Whether this version is non-empty (i.e. a version from a document with no version).
     * The absence of a version is effectively a version, and should be treated as such by consumers
     * of this method.
     */
    var hasVersion: Bool
    {
        get {
            return version != nil
        }
    }

    struct Version: Codable {
        fileprivate enum CodingKeys: String, CodingKey {
            case syncProtocolVersion = "spv"
            case instanceId = "id"
            case versionCounter = "v"
        }
        /// the synchronization protocol version of this version
        let syncProtocolVersion: Int
        /// the GUID instance id of this version
        let instanceId: String
        /// the version counter of this version
        let versionCounter: Int64
    }

    private init(version: Document?,
                 documentId: BSONValue?) {
        if let version = version {
            self.versionDoc = version
            self.version = try? BSONDecoder().decode(Version.self, from: version)
        } else {
            self.versionDoc = nil
            self.version = nil
        }

        if documentId != nil {
            self.filter = getVersionedFilter(documentId: documentId, version: version);
        } else {
            self.filter = nil
        }
    }

    /**
     * Returns the current version info for a locally synchronized document.
     * @param docConfig the CoreDocumentSynchronizationConfig to get the version info from.
     * @return a DocumentVersionInfo
     */
    static func getLocalVersionInfo(docConfig: CoreDocumentSynchronization) -> DocumentVersionInfo {
        return DocumentVersionInfo(
            version: docConfig.lastKnownRemoteVersion,
            documentId: docConfig.documentId.value
        )
    }

    /**
     * Returns the current version info for a provided remote document.
     * @param remoteDocument the remote BSON document from which to extract version info
     * @return a DocumentVersionInfo
     */
    static func getRemoteVersionInfo(remoteDocument: Document) -> DocumentVersionInfo {
        let version = getDocumentVersionDoc(document: remoteDocument)
        return DocumentVersionInfo(
            version: version,
            documentId: remoteDocument["_id"]
        )
    }

    /**
     * Returns a DocumentVersionInfo constructed from a raw version document. The returned
     * DocumentVersionInfo will have no document ID specified, so it will always return a null
     * filter if the filter is requested.
     * @param versionDoc the raw version document from which to extract version info
     * @return a DocumentVersionInfo
     */
    static func fromVersionDoc(versionDoc: Document?) -> DocumentVersionInfo {
        return DocumentVersionInfo(version: versionDoc, documentId: nil)
    }

    /**
     * Returns a BSON version document representing a new version with a new instance ID, and
     * version counter of zero.
     * @return a BsonDocument representing a synchronization version
     */
    static func getFreshVersionDocument() -> Document {
        return [
            Version.CodingKeys.syncProtocolVersion.rawValue: 1,
            Version.CodingKeys.instanceId.rawValue: UUID().uuidString,
            Version.CodingKeys.versionCounter.rawValue: 0
        ]
    }

    /**
     * Returns the version document of the given document, if any; returns null otherwise.
     * @param document the document to get the version from.
     * @return the version of the given document, if any; returns null otherwise.
     */
    static func  getDocumentVersionDoc(document: Document?) -> Document? {
        guard let document = document,
            document.hasKey(DOCUMENT_VERSION_FIELD) else {
            return nil
        }
        return document[DOCUMENT_VERSION_FIELD] as? Document
    }
}
