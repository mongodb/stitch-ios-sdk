These classes are used alongside `StitchAuth` to produce credentials for logging in as a Stitch [user](https://docs.mongodb.com/stitch/users/), and to perform actions related to specific authentication providers. 

For example, the username/password provider provides functionality for registering new users, and sending password reset emails.

Each of the [authentication providers](https://docs.mongodb.com/stitch/authentication/) available for use in MongoDB Stitch have the following constructs in the iOS SDK:

- a client protocol that defines the ways of interacting with the provider and producing credentials for it.
- a class containing a static `ClientProvider` property which conforms to the internal `AuthProviderClientSupplier` protocol. To produce one of the auth provider clients, pass this `ClientProvider` to the `getProviderClient(:forProvider)` method of `StitchAuth`.

As an example, the following code produces a username/password authentication provider client which can be used to register new users:

```swift

let stitchClient = Stitch.getDefaultAppClient()

let userPassAuthClient =
    stitchClient.auth.getProviderClient(forProvider: UserPasswordAuthProvider.ClientProvider)

userPassAuthClient.register(withEmail: "some_user@example.com", withPassword: "hunter2") { (response, error) in
    // Go to next step of user registration flow.
}

```