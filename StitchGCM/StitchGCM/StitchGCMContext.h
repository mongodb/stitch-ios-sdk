//
//  StitchAPNSPushClient.h
//  MongoCore
//
//  Created by Jay Flax on 6/9/17.
//  Copyright © 2017 Zemingo. All rights reserved.
//

#ifndef StitchGCMContext_h
#define StitchGCMContext_h

@import Foundation;
@import UIKit;

@protocol GGLInstanceIDDelegate;
@protocol GCMReceiverDelegate;

@protocol StitchGCMDelegate
-(void)didFailToRegister:(NSError *_Nonnull)error;
-(void)didReceiveToken:(nonnull NSString *)registrationToken;
-(void)didReceiveRemoteNotification:(nonnull UIApplication *)application pushMessage:(nonnull NSDictionary *)pushMessage handler:(void (^_Nullable)(UIBackgroundFetchResult)) handler;
@end

@interface StitchGCMContext: NSObject<GGLInstanceIDDelegate, GCMReceiverDelegate>

@property (readonly, nonatomic) id<StitchGCMDelegate> _Nullable stitchGCMDelegate;

+(StitchGCMContext *_Nonnull) sharedInstance;

-(void)setDelegate:(nonnull id<StitchGCMDelegate>) stitchGCMDelegate;
-(void)setLogging:(BOOL) enabled;

-(BOOL)application:(UIApplication *_Nonnull)application didFinishLaunchingWithOptions:(NSDictionary *_Nullable)launchOptions gcmSenderID:(nonnull NSString *) gcmSenderID stitchGCMDelegate:(nonnull id<StitchGCMDelegate>) stitchGCMDelegate;

- (BOOL)application:(UIApplication *_Nonnull)application didFinishLaunchingWithOptions:(NSDictionary *_Nullable)launchOptions gcmSenderID:(nonnull NSString *)gcmSenderID stitchGCMDelegate:(nonnull id<StitchGCMDelegate>) stitchGCMDelegate uiUserNotificationSettings:(UIUserNotificationSettings *_Nullable)uiUserNotificationSettings;

-(void)subscribeToTopic:(nonnull NSString *) topic;

@end

#endif /* StitchGCMContext_h */
