//
//  DWHSDKTool.h
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/29.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static inline int UserTimeZoneToUTC() {
    NSTimeZone* sourceTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    NSTimeZone* destinationTimeZone = [NSTimeZone localTimeZone];
    NSInteger differenceInSeconds = [destinationTimeZone secondsFromGMT] - [sourceTimeZone secondsFromGMT];
    return (int)round((differenceInSeconds/3600.0));
}

@interface DWHSDKTool : NSObject

+ (NSString *)userDeviceLanguage;
+ (NSString *)userDeviceName;

@end

NS_ASSUME_NONNULL_END
