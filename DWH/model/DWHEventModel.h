//
//  DWHEventModel.h
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/28.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DWHEventModel : NSObject

@property (nonatomic, copy) NSString *eventName;
@property (nonatomic, copy) NSString *attributes;
@property (nonatomic, assign) long long at;
@property (nonatomic, copy) NSString *device_id;
@property (nonatomic, copy) NSString *session_id;

@property (nonatomic, copy, nullable) NSString *uid;
@property (nonatomic, copy, nullable) NSString *account_create_ts;
@property (nonatomic, copy) NSString *userProperties;
@property (nonatomic, assign) int fullTime;
@property (nonatomic, assign) long long occurTime;
@property (nonatomic, assign) int autoGrowthID;

@property (nonatomic, assign) long long localTime;

@end

NS_ASSUME_NONNULL_END
