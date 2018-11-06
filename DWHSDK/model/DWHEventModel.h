//
//  DWHEventModel.h
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/28.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DWHEventModel : NSObject

@property (nonatomic, copy) NSString *auth;
@property (nonatomic, copy) NSString *eventName;
@property (nonatomic, copy) NSString *attributes;
@property (nonatomic, assign) long long at;
@property (nonatomic, copy) NSString *device_id;
@property (nonatomic, copy) NSString *keychain_id;
@property (nonatomic, copy) NSString *session_id;

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *birthday;
@property (nonatomic, copy) NSString *gender;
@property (nonatomic, copy) NSString *nation;
@property (nonatomic, copy) NSString *app_verison;
@property (nonatomic, copy) NSString *ban_status;
@property (nonatomic, copy) NSString *longitude;
@property (nonatomic, copy) NSString *latitude;
@end
