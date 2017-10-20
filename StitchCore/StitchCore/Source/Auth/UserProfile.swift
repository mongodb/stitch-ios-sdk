import Foundation

/**
    UserProfile represents an authenticated user.
 */
public struct UserProfile {

    private static let idKey =              "userId"
    private static let identitiesKey =      "identities"
    private static let dataKey =            "data"

    /**
        The Unique ID of this user within Stitch.
     */
    public private(set) var id: String
    /**
        The set of identities that this user is known by.
     */
    public private(set) var identities: [Identity]
    /**
        The extra data associated with this user.
     */
    public private(set) var data: [String: Any]

    internal var json: [String: Any] {
        return [UserProfile.idKey: id,
                UserProfile.identitiesKey: identities.map {$0.json},
                UserProfile.dataKey: data]
    }

    // MARK: - Init

    internal init(dictionary: [String: Any]) throws {

        guard let id = dictionary[UserProfile.idKey] as? String,
            let identitiesArr = dictionary[UserProfile.identitiesKey] as? [[String: Any]],
            let data = dictionary[UserProfile.dataKey] as? [String: Any] else {
                throw StitchError.responseParsingFailed(reason: "failed creating AuthUser out of info: \(dictionary)")
        }

        var identities: [Identity] = []
        for identityDic in identitiesArr {
            if let identity = Identity(dictionary: identityDic) {
                identities.append(identity)
            }
        }

        self.id = id
        self.identities = identities
        self.data = data
    }

    // MARK: - Identity
    /**
        Identity is an alias by which this user can be authenticated in as.
     */
    public struct Identity {

        private static let idKey =              "id"
        private static let providerKey =        "provider"

        /**
            The provider specific Unique ID.
         */
        private var id: String
        /**
            The provider of this identity.
         */
        private var provider: String

        internal var json: [String: Any] {
            return [Identity.idKey: id,
                    Identity.providerKey: provider]
        }

        init?(dictionary: [String: Any]) {

            guard let id = dictionary[Identity.idKey] as? String,
                let provider = dictionary[Identity.providerKey] as? String else {
                    return nil
            }

            self.id = id
            self.provider = provider
        }
    }
}
