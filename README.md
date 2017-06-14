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

##### Receive Push Notifications in Android

1. In order to listen in on notifications arriving from GCM, we must implement the GCMListenerService
	1. Create a new class called *MyGCMService* in your app's package and use the following code to start with:
	
		```
		package your.app.package.name;
	
		import com.mongodb.stitch.android.push.gcm.GCMListenerService;
		
		public class GCMService extends GCMListenerService {}
		``` 
	2. The included GCMListenerService contains a method called *onPushMessageReceived* that can be overridden to your liking
	3. Now register the service and a receiver in your **AndroidManifest.xml** to pick up on new messages:

		```
		<receiver
		    android:name="com.google.android.gms.gcm.GcmReceiver"
		    android:exported="true"
		    <intent-filter>
		        <action android:name="com.google.android.c2dm.intent.RECEIVE" />
		        <category android:name="your.app.package.name" />
		    </intent-filter>
		</receiver>
		
		<service
		    android:name=".MyGCMService"
		    android:exported="false" >
		    <intent-filter>
		        <action android:name="com.google.android.c2dm.intent.RECEIVE" />
		    </intent-filter>
		</service>
		```
	4. If you'd like to give the service a chance to process the message before sleeping, add the WAKE_LOCK permission to your manifest:

		```
		<uses-permission android:name="android.permission.WAKE_LOCK" />
		```
	
2. Once logged in, you can either create a GCM Push Provider by asking Stitch for the provider information or providing it in your **stitch.properties**
3. To create a GCM Push Provider from properties, simply use the provided factory method:

	```
	final PushClient pushClient = _client.getPush().forProvider(GCMPushProviderInfo.fromProperties());
	```
	* Note: This assumed you've set the **push.gcm.senderId** and **push.gcm.service** property in your **stitch.properties**
	
4. To create a GCM Push Provider by asking Stitch, you must use the *getPushProviders* method and ensure a GCM provider exists:

	```
	self.stitchClient.getPushProviders().response { (result: StitchResult<AvailablePushProviders>) in
                if let gcm = result.value?.gcm {
                    let listener = MyGCMListener(gcmClient: StitchGCMPushClient(stitchClient: self.stitchClient, info: gcm))
                    
                    StitchGCMContext.sharedInstance().application(application,
                                                                  didFinishLaunchingWithOptions: launchOptions,
                                                                  gcmSenderID: "595341599960",
                                                                  stitchGCMDelegate: listener)
                }
        }
	```
5. To begin listening for notifications, set your `StitchGCMDelegate` to the StitchGCMContext:
      	```
	class MyGCMDelegate: StitchGCMDelegate {
            let gcmClient: StitchGCMPushClient
        
            init(gcmClient: StitchGCMPushClient) {
                self.gcmClient = gcmClient
            }
        
            func didFailToRegister(error: Error) {
            
            }
        
            func didReceiveToken(registrationToken: String) {
            
            }
        
	    func didReceiveRemoteNotification(application: UIApplication, pushMessage: PushMessage, handler: ((UIBackgroundFetchResult) -> Void)?) {
            
            }
    	}
	```
6. To register for push notifications, use the *registerToken* method on your StitchClient:

	```
	func didReceiveToken(registrationToken: String) {
            gcmClient.registerToken(token: registrationToken)
        }
	```
