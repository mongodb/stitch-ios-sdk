import ExtendedJSON

public protocol APIStitchUserProfile {
    /**
     * A string describing the type of this user. (Either `server` or `normal`)
     */
    var userType: String { get }

    /**
     * An array of `StitchUserIdentity` objects representing the identities linked
     * to this user which can be used to log in as this user.
     */
    var identities: [StitchUserIdentity] { get }

    /**
     * An object containing extra metadata about the user as supplied by the authentication provider.
     */
    var data: APIExtendedUserProfileImpl { get }
}

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
 * The set of properties that describe a MongoDB Stitch user. See
 * the documentation of the inherited protocols for details about
 * these properties.
 */
public protocol StitchUserProfile: APIStitchUserProfile, ExtendedStitchUserProfile {
}

public final class StitchUserProfileImpl: StitchUserProfile {
    private enum Keys: String {
        case name, email, pictureURL = "picture_url"
        case firstName = "first_name", lastName = "last_name"
        case gender, birthday
        case minAge = "min_age", maxAge = "max_age"
    }

    public lazy var name: String? = data.name

    public lazy var email: String? = data.email

    public lazy var pictureURL: String? = data.pictureURL

    public lazy var firstName: String? = data.firstName

    public lazy var lastName: String? = data.lastName

    public lazy var gender: String? = data.gender

    public lazy var birthday: String? = data.birthday

    public lazy var minAge: Int? = data.minAge

    public lazy var maxAge: Int? = data.maxAge

    public var data: APIExtendedUserProfileImpl

    public var userType: String

    public var identities: [StitchUserIdentity]

    internal init(userType: String, identities: [StitchUserIdentity], data: APIExtendedUserProfileImpl) {
        self.userType = userType
        self.identities = identities
        self.data = data
    }
}
