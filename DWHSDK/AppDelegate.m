//
//  AppDelegate.m
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/27.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import "AppDelegate.h"
#import "DWHSDK.h"
#import "NSDictionary+Extension.h"
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    NSLog(@"uid:%@",[DWHSDK keychain_id]);
    
    [[DWHSDK dwhSDK] setLogLevel:DWHSDKLogLevelInfo];
    NSLog(@"att json:%@",[@{} toJSonString]);
    NSMutableDictionary *dic = [NSMutableDictionary new];
    [dic setValue:[NSNull null] forKey:[NSNull null]];
    NSLog(@"dic:%@",dic);
    [[DWHSDK dwhSDK] initializeProjectId:1 isProductionEnv:false];
    [[DWHSDK dwhSDK] setUserId:5702364 withProperties:@{@"gender":@"M",@"nation":@"Germany",@"timezone":@2}];
//    [[DWHSDK dwhSDK] updateCommonEventProperties:@[@"gender",@"nation"]];
    [[DWHSDK dwhSDK] updateUserProperties:@{@"c":@1,@"e":@(1.89765)}];
//    dispatch_queue_t t =  dispatch_queue_create("hw_queue_event_handle", DISPATCH_QUEUE_CONCURRENT);
//    dispatch_async(t, ^{
//        [[DWHSDK dwhSDK] logEvent:@"aaaa" withEventProperties:@{@"aaa":@"bbb"}];
//    });
//    dispatch_async(t, ^{
//       [[DWHSDK dwhSDK] updateUserProperties:@{@"c":@1,@"e":@(1.89765)}];
//    });
//    dispatch_async(t, ^{
//        [[DWHSDK dwhSDK] logEvent:@"bbbbb" withEventProperties:@{@"ccccc":@"bbb"}];
//    });
//    dispatch_async(t, ^{
//        [[DWHSDK dwhSDK] updateUserProperties:@{@"c":@1,@"e":@(1.89765)}];
//    });
//    dispatch_async(t, ^{
//        [[DWHSDK dwhSDK] logEvent:@"ddddddd" withEventProperties:@{@"eeeeee":@"bbb"}];
//    });
//    dispatch_async(t, ^{
//        [[DWHSDK dwhSDK] updateUserProperties:@{@"c":@1,@"e":@(1.89765)}];
//    });
//    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        for (int i=0; i<100; i++) {
//            [[DWHSDK dwhSDK] updateUserProperties:@{@"f":@1,@"s":@(1),@"i":@(i)}];
//        }
//    });
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
