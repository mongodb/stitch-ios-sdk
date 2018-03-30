Follow these instructions to get started with the MongoDB Stitch iOS SDK.

### Set up an application on Stitch

1. Go to https://stitch.mongodb.com/ and log in
2. Create a new app with your desired name
3. Take note of the app's client App ID by going to Clients under Platform in the side pane
4. Go to Authentication under Control in the side pane and enable "Allow users to log in anonymously"

### Set up a project in XCode using Stitch

TODO: For STITCH-1293, Replace this with instructions on how to integrate the SDK into an XCode project. Instructions should be given for each of the package managers we'll support, as well as making the SDK an embedded framework.

### Using the SDK

#### Logging In

1. To initialize our connection to Stitch, use the static `Stitch.initialize()`  and `Stitch.initializeDefaultAppClient()` methods to initialize the SDK and prepare a default `StitchAppClient`. This code can be placed in your `AppDelegate`'s `application(_, didFinishLaunchingWithOptions)` method:

    ```swift
    do {
        try Stitch.initialize()
        _ = try Stitch.initializeDefaultAppClient(
            withConfigBuilder: StitchAppClientConfigurationBuilder.init({
            $0.clientAppId = "<your-client-app-id>"
        }))
        return true
    } catch {
        print("Failed to initialize MongoDB Stitch iOS SDK: \(error.localizedDescription)")
        return false
    }
    ```

2. We enabled anonymous log in, so let's log in with it; add the following in one of your view controllers:

    ```swift
    let stitchClient: StitchAppClient! = try? Stitch.getDefaultAppClient()
    let anonAuthClient =
        stitchClient.auth.providerClient(forProvider: AnonymousAuthProvider.clientProvider)
    stitchClient.auth.login(withCredential: anonAuthClient.credential) { user, error in
        if let error = error {
            print("Failed to log in: \(error)")
        } else if let user = user {
            print("Logged in as user \(user.id)")
            DispatchQueue.main.async {
                // Update UI accordingly
            }
        }
    }
    ```

3. Now run your app in XCode by going to product, Run (or hitting ⌘R).
4. Once the app is running, open up the Debug Area by going to View, Debug Area, Show Debug Area.
5. You should see a log message like:

    ```
    Logged in as user 58c5d6ebb9ede022a3d75050
    ```

#### Executing a Function

1. Once logged in, executing a function happens via the StitchClient's `executeFunction()` method

	```swift
    stitchClient.callFunction(withName: "echoArg", withArgs: ["Hello world!"]) { (value, error) in
        print("Message: \(value ?? "None")\nError: \(String(describing: error))")
    }
	```

2. If you've configured your Stitch application to have a function named "echoArg" that returns its argument, you should see a message like:

    ```
    Message: Hello world!
    Error: nil
    ```

3. The source of the "echoArg" function in Stitch could look something like this:
    ```javascript
    exports = function(arg){
        return arg;
    };
    ```