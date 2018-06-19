[![Join the chat at https://gitter.im/mongodb/stitch](https://badges.gitter.im/mongodb/stitch.svg)](https://gitter.im/mongodb/stitch?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) ![iOS](https://img.shields.io/badge/platform-iOS-blue.svg) [![Swift 4.0](https://img.shields.io/badge/swift-4.0-orange.svg)](https://developer.apple.com/swift/) ![Apache 2.0 License](https://img.shields.io/badge/license-Apache%202-lightgrey.svg) [![Cocoapods compatible](https://img.shields.io/badge/pod-v1.0.0-ff69b4.svg)](#CocoaPods)

# MongoDB Stitch iOS/Swift SDK 

The official [MongoDB Stitch](https://stitch.mongodb.com/) SDK for iOS/Swift.

### Index
- [Documentation](#documentation)
- [Discussion](#discussion)
- [Installation](#installation)
- [Example Usage](#example-usage)

## Documentation
* [API/Jazzy Documentation](https://s3.amazonaws.com/stitch-sdks/android/docs/4.0.0/index.html)
* [MongoDB Stitch Documentation](https://docs.mongodb.com/stitch/)

## Discussion
* [MongoDB Stitch Users - Google Group](https://groups.google.com/d/forum/mongodb-stitch-users)
* [MongoDB Stitch Announcements - Google Group](https://groups.google.com/d/forum/mongodb-stitch-announce)

## Installation

### XCode/iOS

#### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 1.1.0+ is required to build Stitch iOS 0.2.0+.

To integrate the iOS SDK into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '11.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'StitchSDK', '~> 4.0.0'

    # optional: for using the AWS S3 service
    pod 'StitchSDK/StitchAWSS3Service', '~> 4.0.0'
    # optional: for using the AWS SES service
    pod 'StitchSDK/StitchAWSSESService', '~> 4.0.0'
    # optional: for using the Firebase Cloud Messaging service
    pod 'StitchSDK/StitchFCMService', '~> 4.0.0'
    # optional: for using the HTTP service
    pod 'StitchSDK/StitchHTTPService', '~> 4.0.0'
    # optional: for using the Local MongoDB service
    pod 'StitchSDK/StitchLocalMongoDBService', '~> 4.0.0'
    # optional: for using the twilio service
    pod 'StitchSDK/StitchTwilioService', '~> 4.0.0'
end
```

Then, run the following command:

```bash
$ pod install
```

#### Manually

// TODO: Update this to reflect the process once we've figured out Pods.

If you prefer not to use any of the aforementioned dependency managers, you can integrate the iOS SDK into your project manually as an embedded framework.

- Open up Terminal, `cd` into your top-level project directory, and run the following command "if" your project is not initialized as a git repository:

  ```bash
  $ git init
  ```

- Add the iOS SDK as a git [submodule](http://git-scm.com/docs/git-submodule) by running the following command:

  ```bash
  $ git submodule add https://github.com/10gen/stitch-ios-sdk.git
  ```

- `cd` into stitch-ios-sdk, and run `make`.

- Open the new `stitch-ios-sdk` folder, and drag the `StitchCore.xcodeproj` into the Project Navigator of your application's Xcode project.

    > It should appear nested underneath your application's blue project icon. Whether it is above or below all the other Xcode groups does not matter.

- Select the `StitchCore-iOS.xcodeproj` in the Project Navigator and verify the deployment target matches that of your application target.
- Next, select your application project in the Project Navigator (blue project icon) to navigate to the target configuration window and select the application target under the "Targets" heading in the sidebar.
- In the tab bar at the top of that window, open the "General" panel.
- Click on the `+` button under the "Embedded Binaries" section.
- You will see two different `StitchCore.xcodeproj` folders each with two different versions of the `StitchCore.framework` nested inside a `Products` folder.

    > It does not matter which `Products` folder you choose from, but it does matter whether you choose the top or bottom `StitchCore.framework`.

- Select the `StitchCore-iOS.framework` for iOS.

- Click on your .xcodeproj within XCode. Under the `Build Settings` tab, scroll down to `Header Search Paths` and add `$(SRCROOT)/stitch-ios-sdk/Sources/libbson` and `$(SRCROOT)/stitch-ios-sdk/Sources/libmongoc`.

- Scroll down to `Library Search Paths` and add `$(SRCROOT)/stitch-ios-sdk/MobileSDKs/iphoneos/lib`.

- For adding the other modules, `StitchCoreServicesTwilio-iOS`, follow the same process above but with the respective `.xcodeproj` files.

- And that's it!

  > The `StitchCore.framework` is automagically added as a target dependency, linked framework and embedded framework in a copy files build phase which is all you need to build on the simulator and a device.

---

## Example Usage

### Creating a new app with the SDK (iOS)

#### Set up an application on Stitch
1. Go to [https://stitch.mongodb.com/](https://stitch.mongodb.com/) and log in to MongoDB Atlas.
2. Create a new app in your project with your desired name.
3. Go to your app in Stitch via Atlas by clicking Stitch Apps in the left side pane and clicking your app.
3. Copy your app's client app id by going to Clients on the left side pane and clicking copy on the App ID section.
4. Go to Providers from Users in the left side pane and edit and enable "Allow users to log in anonymously".

#### Set up a project in XCode/CocoaPods using Stitch

1. Download and install [XCode](https://developer.apple.com/xcode/)
2. Create a new app project with your desired name. Ensure that Swift is the selected language.
3. Navigate to the directory of the project in a command line, and run `pod init`.
4. In the `Podfile` that is generated, add the following line under the dependencies for your app target:

```ruby
    pod 'StitchSDK', '~> 4.0.0'
```

5. Run `pod install`
6. Open the generated `.xcworkspace` file
7. Your app project will have all the necessary dependencies configured to communicate with MongoDB Stitch.

#### Using the SDK

#### Initialize the SDK
1. When your app is initialized, run the following code to initialize the Stitch SDK. The [`application(_:didFinishLaunchWithOptions)`](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622921-application) method of your `AppDelegate.swift` can be an appropriate place for this initialization step.

```swift
    do {
        try Stitch.initialize()
        
        _ = try Stitch.initializeDefaultAppClient(withConfigBuilder:
            StitchAppClientConfigurationBuilder.forApp(withClientAppID: "your-client-app-id")
        )
    } catch {
        print("Failed to initialize MongoDB Stitch iOS SDK: \(error.localizedDescription)")
        // note: This initialization will only fail if an incomplete configuration is 
        // passed to a client initialization method, or if a client for a particular 
        // app ID is initialized multiple times. See the documentation of the "Stitch" 
        // class for more details.
    }
```

2. To get a client to use for logging in and communicating with Stitch, use `Stitch.defaultAppClient`.

```swift
    // in a view controller's properties, for example
    private lazy var stitchClient = Stitch.defaultAppClient!
```

##### Logging In
1. We enabled anonymous log in, so let's log in with it; add the following anywhere in your code:

```swift
let client = Stitch.defaultAppClient!

print("logging in anonymously")
client.auth.login(withCredential: AnonymousCredential()) { result in
        switch result {
        case .success(let user):
            print("logged in anonymous as user \(user.id)")
            DispatchQueue.main.async {
                // update UI accordingly
            }
        case .failure(let error):
            print("Failed to log in: \(error)")
        }
    }
```

2. Now run your app in XCode by going to product, Run (or hitting ⌘R).
3. Once the app is running, open up the Debug Area by going to View, Debug Area, Show Debug Area.
4. You should see log messages like:

```
logging in anonymously                                                    	
logged in anonymously as user 58c5d6ebb9ede022a3d75050
```

##### Executing a Function

1. Once logged in, executing a function happens via the StitchClient's `executeFunction()` method

```swift
    client.callFunction(
        withName: "echoArg", withArgs: ["Hello world!"], withRequestTimeout: 5.0
    ) { (result: StitchResult<String>) in
        switch result {
        case .success(let stringResult):
            print("String result: \(stringResult)")
        case .failure(let error):
            print("Error retrieving String: \(String(describing: error))")
        }
    }
```

2. If you've configured your Stitch application to have a function named "echoArg" that returns its argument, you should see a message like:

```
String result: Hello world!
```

##### Getting a StitchAppClient without Stitch.defaultAppClient

In the case that you don't want a single default initialized StitchAppClient by setting up the resource values, you can use the following with as many client app IDs as you'd like to initialize clients for a multiple app IDs:

```swift
    do {
        try Stitch.initialize()
        
        let client1 = try Stitch.initializeAppClient(withConfigBuilder:
            StitchAppClientConfigurationBuilder.forApp(withClientAppID: "your-first-client-app-id")
        )
        let client2 = try Stitch.initializeAppClient(withConfigBuilder:
            StitchAppClientConfigurationBuilder.forApp(withClientAppID: "your-second-client-app-id")
        )
    } catch {
        print("Failed to initialize MongoDB Stitch iOS SDK: \(error.localizedDescription)")
    }
```

You can use the client returned there or anywhere else in your app you can use the following:


```swift
let client1 = try! Stitch.appClient(forAppID: "your-first-client-app-id")
let client2 = try! Stitch.appClient(forAppID: "your-second-client-app-id")
```