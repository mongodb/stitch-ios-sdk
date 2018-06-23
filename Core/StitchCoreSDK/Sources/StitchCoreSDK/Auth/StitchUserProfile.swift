import MongoSwift

/**
 * :nodoc:
 * A protocol containing the fields returned by the Stitch client API in a user profile request.
 */
public protocol APIStitchUserProfile {
    /**
     * A string describing the type of this user. (Either `server` or `normal`)
     */
    var userType: String { get }

    /**
     * An array of `StitchUserIdentity` objects representing the identities linked
     * to this user which can be used to log in as this user.
     */
    var identities: [APIStitchUserIdentity] { get }

    /**
     * An object containing extra metadata about the user as supplied by the authentication provider.
     */
    var data: APIExtendedUserProfileImpl { get }
}

/**
 * A protocol containing the fields returned by the Stitch client API in the `data` field of a user profile request.
 */
public protocol ExtendedStitchUserProfile {
    /**
     * The full name of the user.
     */
    var name: String? { get }

    /**
     * The email address of the user.
     */
    var email: String? { get }

    /**
     * A URL to the user's profile picture.
     */
    var pictureURL: String? { get }

    /**
     * The first name of the user.
     */
    var firstName: String? { get }

    /**
     * The last name of the user.
     */
    var lastName: String? { get }

    /**
     * The gender of the user.
     */
    var gender: String? { get }

    /**
     * The birthdate of the user.
     */
    var birthday: String? { get }

    /**
     * The minimum age of the user.
     */
    var minAge: Int? { get }

    /**
     * The maximum age of the user.
     */
    var maxAge: Int? { get }
}

/**
 * The set of properties that describe a MongoDB Stitch user. See the documentation for `ExtendedStitchUserProfile` to
 * see the additional fields available on this type.
 */
public protocol StitchUserProfile: ExtendedStitchUserProfile {
    /**
     * A string describing the type of this user. (Either `server` or `normal`)
     */
    var userType: String { get }
    
    /**
     * An array of `StitchUserIdentity` objects representing the identities linked
     * to this user which can be used to log in as this user.
     */
    var identities: [StitchUserIdentity] { get }
    
    /// :nodoc:
    var data: APIExtendedUserProfileImpl { get }
}

/**
 * An implementation of `StitchUserProfile`.
 */
internal final class StitchUserProfileImpl: StitchUserProfile {
    private enum Keys: String {
        case name, email, pictureURL = "picture_url"
        case firstName = "first_name", lastName = "last_name"
        case gender, birthday
        case minAge = "min_age", maxAge = "max_age"
    }

    /**
     * The full name of the user.
     */
    public lazy var name: String? = self.data.name

    /**
     * The email address of the user.
     */
    public lazy var email: String? = self.data.email

    /**
     * A URL to the user's profile picture.
     */
    public lazy var pictureURL: String? = self.data.pictureURL

    /**
     * The first name of the user.
     */
    public lazy var firstName: String? = self.data.firstName

    /**
     * The last name of the user.
     */
    public lazy var lastName: String? = self.data.lastName

    /**
     * The gender of the user.
     */
    public lazy var gender: String? = self.data.gender

    /**
     * The birthdate of the user.
     */
    public lazy var birthday: String? = self.data.birthday

    /**
     * The minimum age of the user.
     */
    public lazy var minAge: Int? = self.data.minAge

    /**
     * The maximum age of the user.
     */
    public lazy var maxAge: Int? = self.data.maxAge

    /**
     * An object containing extra metadata about the user as supplied by the authentication provider. This need not
     * be accessed directly, since all of its properties are exposed as computed properties in this class.
     */
    public var data: APIExtendedUserProfileImpl

    /**
     * A string describing the type of this user. (Either `server` or `normal`)
     */
    public var userType: String

    /**
     * An array of `StitchUserIdentity` objects representing the identities linked
     * to this user which can be used to log in as this user.
     */
    public var identities: [StitchUserIdentity]

    /**
     * Initializes the user profile with its properties as arguments.
     */
    internal init(userType: String, identities: [StitchUserIdentity], data: APIExtendedUserProfileImpl) {
        self.userType = userType
        self.identities = identities
        self.data = data
    }
}
