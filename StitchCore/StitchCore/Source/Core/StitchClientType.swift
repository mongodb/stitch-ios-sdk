import Foundation

/// Protocol to lay out basic methods and fields for a StitchClient.
public protocol StitchClientType {

    // MARK: - Properties
    /// Id of this application
    var appId: String { get }
    /// The currently authenticated user (if authenticated).
    var auth: Auth? { get }
    /// Whether or not this client is authenticated.
    var isAuthenticated: Bool { get }

    // MARK: - Auth

    /**
        Fetches all available auth providers for the current app.
     
        - Returns: A task containing AuthProviderInfo that can be resolved 
                    on completion of the request.
     */
    @discardableResult
    func fetchAuthProviders() -> StitchTask<AuthProviderInfo>

    /**
        Registers the current user using email and password.
     
        - parameter email: email for the given user
        - parameter password: password for the given user
        - returns: A task containing whether or not registration was successful.
     */
    @discardableResult
    func register(email: String, password: String) -> StitchTask<Void>

    /**
     * Confirm a newly registered email in this context
     * - parameter token: confirmation token emailed to new user
     * - parameter tokenId: confirmation tokenId emailed to new user
     * - returns: A task containing whether or not the email was confirmed successfully
     */
    @discardableResult
    func emailConfirm(token: String, tokenId: String) -> StitchTask<Any>

    /**
     * Send a confirmation email for a newly registered user
     * - parameter email: email address of user
     * - returns: A task containing whether or not the email was sent successfully.
     */
    @discardableResult
    func sendEmailConfirm(toEmail email: String) -> StitchTask<Void>

    /**
     * Reset a given user's password
     * - parameter token: token associated with this user
     * - parameter tokenId: id of the token associated with this user
     * - returns: A task containing whether or not the reset was successful
     */
    @discardableResult
    func resetPassword(token: String, tokenId: String) -> StitchTask<Any>

    /**
     * Send a reset password email to a given email address
     * - parameter email: email address to reset password for
     * - returns: A task containing whether or not the reset email was sent successfully
     */
    @discardableResult
    func sendResetPassword(toEmail email: String) -> StitchTask<Void>

    /**
     Logs the current user in anonymously.
     
     - Returns: A task containing whether or not the login as successful
     */
    @discardableResult
    func anonymousAuth() -> StitchTask<Bool>

    /**
        Logs the current user in using a specific auth provider.
     
        - Parameters:
            - withProvider: The provider that will handle the login.
            - link: Whether or not to link a new auth provider.
        - Returns: A task containing whether or not the login as successful
     */
    @discardableResult
    func login(withProvider provider: AuthProvider, link: Bool) -> StitchTask<Bool>

    /**
     * Logs out the current user.
     *
     * - returns: A task that can be resolved upon completion of logout.
     */
    @discardableResult
    func logout() -> StitchTask<Bool>

    // MARK: - Requests

    /**
     * Executes a pipeline with the current app.
     *
     * - parameter stages: The stages to execute as a contiguous pipeline.
     * - returns: A task containing the result of the pipeline that can be resolved on completion
     * of the execution.
     */
    @discardableResult
    func executePipeline(pipeline: Pipeline) -> StitchTask<Any>

    /**
     * Executes a pipeline with the current app.
     *
     * - parameter pipeline: The pipeline to execute.
     * - returns: A task containing the result of the pipeline that can be resolved on completion
     * of the execution.
     */
    @discardableResult
    func executePipeline(pipelines: [Pipeline]) -> StitchTask<Any>

    /**
        Adds a delegate for auth events.
     
        - parameter delegate: The delegate that will receive auth events.
     */
    func addAuthDelegate(delegate: AuthDelegate)
}

// MARK: - Default Values
public extension StitchClientType {

    @discardableResult
    func login(withProvider provider: AuthProvider, link: Bool = false) -> StitchTask<Bool> {
        return login(withProvider: provider, link: link)
    }
}
