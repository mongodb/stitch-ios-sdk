//
//  StitchGCMContext.m
//  MongoCore
//
//  Created by Jay Flax on 6/9/17.
//  Copyright © 2017 Zemingo. All rights reserved.
//


#import "StitchGCMContext.h"
#import <objc/runtime.h>
#import <StitchGCM/StitchGCM-Swift.h>
#import <StitchCore/StitchCore-Swift.h>

@implementation StitchGCMContext

static StitchGCMContext* sharedInstance;

IMP applicationDidFinishLaunchingWithOptions;
IMP applicationDidBecomeActive;
IMP applicationDidEnterBackground;
IMP applicationDidRegisterForRemoteNotifications;
IMP applicationDidFailToRegisterForRemoteNotifications;
IMP applicationDidReceiveRemoteNotification;
IMP applicationDidReceiveRemoteNotificationHandler;

NSString *const SubscriptionTopic = @"/topics/global";
NSDictionary *stitchClients;

static bool _connectedToGCM = false;
static bool _subscribedToTopic = false;
static NSString *_gcmSenderID;
static NSString *_registrationToken;
static NSDictionary *_registrationOptions;

static NSString *_registrationKey = @"onRegistrationCompleted";
static NSString *_messageKey = @"onMessageReceived";
static NSString *_subscriptionTopic = @"/topics/global";
static void (^registrationHandler)();

-(IMP)swizzleMethod:(SEL)originalSelector swizzleSelector:(SEL) swizzleSelector {
    Class class = [[[UIApplication sharedApplication] delegate] class];
    
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod([self class], swizzleSelector);
    
    IMP originalMethodImp = method_getImplementation(originalMethod);
    
    
    BOOL didAddMethod =
    class_addMethod(class,
                    originalSelector,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class,
                            swizzleSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
    
    return originalMethodImp;
}

+(StitchGCMContext *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [StitchGCMContext new];
    }
    
    return sharedInstance;
}

-(void)setDelegate:(id<StitchGCMDelegate>) stitchGCMDelegate {
    _stitchGCMDelegate = stitchGCMDelegate;
}

// [START register_for_remote_notifications]
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions gcmSenderID:(NSString *)gcmSenderID stitchGCMDelegate:(id<StitchGCMDelegate>) stitchGCMDelegate {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        applicationDidBecomeActive = [self swizzleMethod:@selector(applicationDidBecomeActive:)
                                   swizzleSelector:@selector(_applicationDidBecomeActive:)];
        
        applicationDidEnterBackground = [self swizzleMethod:@selector(applicationDidEnterBackground:)
                                      swizzleSelector:@selector(_applicationDidEnterBackground:)];
        
        applicationDidRegisterForRemoteNotifications = [self swizzleMethod:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
                                                     swizzleSelector:@selector(_application:didRegisterForRemoteNotificationsWithDeviceToken:)];
        
        applicationDidFailToRegisterForRemoteNotifications = [self swizzleMethod:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)
                                                           swizzleSelector:@selector(_application:didFailToRegisterForRemoteNotificationsWithError:)];
        
        applicationDidReceiveRemoteNotification = [self swizzleMethod:@selector(application:didReceiveRemoteNotification:)
                                                swizzleSelector:@selector(_application:didReceiveRemoteNotification:)];
        
        applicationDidReceiveRemoteNotificationHandler = [self swizzleMethod:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
                                                       swizzleSelector:@selector(_application:didReceiveRemoteNotification:fetchCompletionHandler:)];
        
        return;
    });
    
    _gcmSenderID = gcmSenderID;
    _stitchGCMDelegate = stitchGCMDelegate;
    
    // [START_EXCLUDE]
    // Configure the Google context: parses the GoogleService-Info.plist, and initializes
    // the services that have entries in the file
    NSError* configureError;
    [[UIApplication sharedApplication] delegate];
    [[GGLContext sharedInstance] configureWithError:&configureError];
    NSAssert(!configureError, @"Error configuring Google services: %@", configureError);
    // Register for remote notifications
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        // iOS 7.1 or earlier
        UIRemoteNotificationType allNotificationTypes =
        (UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge);
        [application registerForRemoteNotificationTypes:allNotificationTypes];
    } else {
        // iOS 8 or later
        // [END_EXCLUDE]
        UIUserNotificationType allNotificationTypes =
        (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
    // [END register_for_remote_notifications]
    // [START start_gcm_service]
    GCMConfig *gcmConfig = [GCMConfig defaultConfig];
    gcmConfig.receiverDelegate = self;
    [[GCMService sharedInstance] startWithConfig:gcmConfig];
    // [END start_gcm_service]
    // Handler for registration token request
    registrationHandler = ^(NSString *registrationToken, NSError *error) {
        if (registrationToken != nil) {
            
            [stitchGCMDelegate didReceiveTokenWithRegistrationToken:registrationToken];

            _registrationToken = registrationToken;
            
            NSLog(@"Registration Token: %@", registrationToken);
            [StitchGCMContext subscribeToTopic];
            NSDictionary *userInfo = @{@"registrationToken":registrationToken};
            [[NSNotificationCenter defaultCenter] postNotificationName:_registrationKey
                                                                object:nil
                                                              userInfo:userInfo];
        } else {
            [[[StitchGCMContext sharedInstance] stitchGCMDelegate] didFailToRegisterWithError: error];

            NSLog(@"Registration to GCM failed with error: %@", error.localizedDescription);
            NSDictionary *userInfo = @{@"error":error.localizedDescription};
            [[NSNotificationCenter defaultCenter] postNotificationName:_registrationKey
                                                                object:nil
                                                              userInfo:userInfo];
        }
    };
    return YES;
}


+(void)subscribeToTopic {
    // If the app has a registration token and is connected to GCM, proceed to subscribe to the
    // topic
    if (_registrationToken && _connectedToGCM) {
        [[GCMPubSub sharedInstance] subscribeWithToken:_registrationToken
                                                 topic:SubscriptionTopic
                                               options:nil
                                               handler:^(NSError *error) {
                                                   if (error) {
                                                       // Treat the "already subscribed" error more gently
                                                       if (error.code == 3001) {
                                                           NSLog(@"Already subscribed to %@",
                                                                 SubscriptionTopic);
                                                       } else {
                                                           NSLog(@"Subscription failed: %@",
                                                                 error.localizedDescription);
                                                       }
                                                   } else {
                                                       _subscribedToTopic = true;
                                                       NSLog(@"Subscribed to %@", SubscriptionTopic);
                                                   }
                                               }];
    }
}

// [START connect_gcm_service]
- (void)_applicationDidBecomeActive:(UIApplication *)application {
    // Connect to the GCM server to receive non-APNS notifications
    [[GCMService sharedInstance] connectWithHandler:^(NSError *error) {
        if (error) {
            NSLog(@"Could not connect to GCM: %@", error.localizedDescription);
        } else {
            _connectedToGCM = true;
            NSLog(@"Connected to GCM");
            // [START_EXCLUDE]
            [StitchGCMContext subscribeToTopic];
            // [END_EXCLUDE]
        }
    }];
}

// [START disconnect_gcm_service]
- (void)_applicationDidEnterBackground:(UIApplication *)application {
    [[GCMService sharedInstance] disconnect];
    // [START_EXCLUDE]
    _connectedToGCM = NO;
    // [END_EXCLUDE]
}
// [END disconnect_gcm_service]

// [START receive_apns_token]
- (void)_application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // [END receive_apns_token]
    // [START get_gcm_reg_token]
    // Create a config and set a delegate that implements the GGLInstaceIDDelegate protocol.
    GGLInstanceIDConfig *instanceIDConfig = [GGLInstanceIDConfig defaultConfig];
    instanceIDConfig.delegate = self;
    // Start the GGLInstanceID shared instance with the that config and request a registration
    // token to enable reception of notifications
    [[GGLInstanceID sharedInstance] startWithConfig:instanceIDConfig];
    
    _registrationOptions = @{kGGLInstanceIDRegisterAPNSOption:deviceToken,
                             kGGLInstanceIDAPNSServerTypeSandboxOption:@YES};
    
    [[GGLInstanceID sharedInstance] tokenWithAuthorizedEntity:_gcmSenderID
                                                        scope:kGGLInstanceIDScopeGCM
                                                      options:_registrationOptions
                                                      handler:registrationHandler];
    // [END get_gcm_reg_token]
}

// [START receive_apns_token_error]
- (void)_application:(UIApplication *)application
didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    [[[StitchGCMContext sharedInstance] stitchGCMDelegate] didFailToRegisterWithError: error];

    NSLog(@"Registration for remote notification failed with error: %@", error.localizedDescription);
    // [END receive_apns_token_error]
    NSDictionary *userInfo = @{@"error" :error.localizedDescription};
    [[NSNotificationCenter defaultCenter] postNotificationName:_registrationKey
                                                        object:nil
                                                      userInfo:userInfo];
}

// [START ack_message_reception]
- (void)_application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSLog(@"Notification received: %@", userInfo);
    // This works only if the app started the GCM service
    [[GCMService sharedInstance] appDidReceiveMessage:userInfo];
    // Handle the received message
    // [START_EXCLUDE]
    [[NSNotificationCenter defaultCenter] postNotificationName:_messageKey
                                                        object:nil
                                                      userInfo:userInfo];

    
    [[[StitchGCMContext sharedInstance] stitchGCMDelegate] didReceiveRemoteNotificationWithApplication:application pushMessage: [PushMessage fromGCMWithData:userInfo] handler: nil];
    // [END_EXCLUDE]
}

- (void)_application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))handler {
    NSLog(@"Notification received: %@", userInfo);
    // This works only if the app started the GCM service
    [[GCMService sharedInstance] appDidReceiveMessage:userInfo];
    // Handle the received message
    // Invoke the completion handler passing the appropriate UIBackgroundFetchResult value
    // [START_EXCLUDE]
    [[NSNotificationCenter defaultCenter] postNotificationName:_messageKey
                                                        object:nil
                                                      userInfo:userInfo];
    
    [[[StitchGCMContext sharedInstance] stitchGCMDelegate] didReceiveRemoteNotificationWithApplication:application pushMessage: [PushMessage fromGCMWithData:userInfo] handler: handler];

    handler(UIBackgroundFetchResultNoData);
    // [END_EXCLUDE]
}
// [END ack_message_reception]

// [START on_token_refresh]
/**
 *  Called when the system determines that tokens need to be refreshed.
 *  This method is also called if Instance ID has been reset in which
 *  case, tokens and `GcmPubSub` subscriptions also need to be refreshed.
 *
 *  Instance ID service will throttle the refresh event across all devices
 *  to control the rate of token updates on application servers.
 */
- (void)onTokenRefresh {
    // A rotation of the registration tokens is happening, so the app needs to request a new token.
    NSLog(@"The GCM registration token needs to be changed.");
    [[GGLInstanceID sharedInstance] tokenWithAuthorizedEntity:_gcmSenderID
                                                        scope:kGGLInstanceIDScopeGCM
                                                      options:_registrationOptions
                                                      handler:registrationHandler];
}
// [END on_token_refresh]

// [START upstream_callbacks]
- (void)willSendDataMessageWithID:(NSString *)messageID error:(NSError *)error {
    if (error) {
        // Failed to send the message.
    } else {
        // Will send message, you can save the messageID to track the message
    }
}

- (void)didSendDataMessageWithID:(NSString *)messageID {
    // Did successfully send message identified by messageID
}
// [END upstream_callbacks]

- (void)didDeleteMessagesOnServer {
    // Some messages sent to this device were deleted on the GCM server before reception, likely
    // because the TTL expired. The client should notify the app server of this, so that the app
    // server can resend those messages.
}

@end
