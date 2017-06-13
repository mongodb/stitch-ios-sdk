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

#import <Google/CloudMessaging.h>

@protocol StitchGCMDelegate;

@interface StitchGCMContext: NSObject<GGLInstanceIDDelegate, GCMReceiverDelegate>

@property (readonly, nonatomic) id<StitchGCMDelegate> _Nullable stitchGCMDelegate;

+(StitchGCMContext *_Nonnull) sharedInstance;

-(void)setDelegate:(nonnull id<StitchGCMDelegate>) stitchGCMDelegate;

-(BOOL)application:(UIApplication *_Nonnull)application didFinishLaunchingWithOptions:(NSDictionary *_Nullable)launchOptions gcmSenderID:(nonnull NSString *) gcmSenderID stitchGCMDelegate:(nonnull id<StitchGCMDelegate>) stitchGCMDelegate;

@end

#endif /* StitchGCMContext_h */
