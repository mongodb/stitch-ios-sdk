/**
 * :nodoc:
 * The anonymous authentication provider which provides basic information for log in.
 */
public final class AnonymousAuthProvider {
    private init() {}
    
    public static let type = "anon-user"
    public static let defaultName = "anon-user"
}
