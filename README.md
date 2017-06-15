# iOS SDK


## Creating a new app with the SDK

### Set up an application on Stitch
1. Go to https://stitch.mongodb.com/ and log in
2. Create a new app with your desired name
3. Take note of the app's client App ID by going to Clients under Platform in the side pane
4. Go to Authentication under Control in the side pane and enable "Allow users to log in anonymously"

### Set up a project in XCode using Stitch

TODO: Write set up instructions.

### Using the SDK

TODO: Write usage instructions.

#### Set up Push Notifications (GCM)

##### Set up a GCM provider

1. Create a Firebase Project
2. Click Add Firebase to your iOS app
3. Skip downloading the config file
4. Skip adding the Firebase SDK
5. Click the gear next to overview in your Firebase project and go to Project Settings
6. Go to Cloud Messaging and take note of your Legacy server key and Sender ID
7. In Stitch go to the Notifications section and enter in your API Key (legacy server key) and Sender ID

##### Receive Push Notifications in iOS

1. TODO: Write enabling push.

2. To create a GCM Push Provider by asking Stitch, you must use the *getPushProviders* method and ensure a GCM provider exists:

```swift
self.stitchClient.getPushProviders().response { (result: StitchResult<AvailablePushProviders>) in
    if let gcm = result.value?.gcm {
        let listener = MyGCMListener(gcmClient: StitchGCMPushClient(stitchClient: self.stitchClient, info: gcm))

	StitchGCMContext.sharedInstance().application(application,
						      didFinishLaunchingWithOptions: launchOptions,
						      gcmSenderID: "<YOUR-GCM-SENDER-ID>",
						      stitchGCMDelegate: listener)
    }
}
```

3. To begin listening for notifications, set your `StitchGCMDelegate` to the StitchGCMContext:

```swift
class MyGCMDelegate: StitchGCMDelegate {
    let gcmClient: StitchGCMPushClient
        
    init(gcmClient: StitchGCMPushClient) {
        self.gcmClient = gcmClient
    }
        
    func didFailToRegister(error: Error) {
            
    }
        
    func didReceiveToken(registrationToken: String) {
            
    }
        
    func didReceiveRemoteNotification(application: UIApplication, 
				      pushMessage: PushMessage,
				      handler: ((UIBackgroundFetchResult) -> Void)? 
									  
    }
}
```

4. To register for push notifications, use the *registerToken* method on your StitchClient:

```swift
func didReceiveToken(registrationToken: String) {
    gcmClient.registerToken(token: registrationToken)
}
```
