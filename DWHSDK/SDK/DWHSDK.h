//
//  DWHSDK.h
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/27.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    DWHSDKLogLevelInfo,
    DWHSDKLogLevelWarning,
    DWHSDKLogLevelError,
    DWHSDKLogLevelNone,
} DWHSDKLogLevel;
@interface DWHSDK : NSObject

+ (instancetype)dwhSDK;

+ (NSString *)sdkVersion;

- (void)setLogLevel:(DWHSDKLogLevel)logLevel;
/**
 秒
 **/
- (void)setServerTime:(long long)serverTime;
/**
 初始化
 isProduction = false测试环境 会显示日志 测试服务器地址
 */
- (void)initializeProjectId:(NSInteger)projectId isProductionEnv:(BOOL)isProduction;

/*
 设置用户属性，启动sdk,获取auth
 
 默认用户属性
 @[@"timezone",@"device_language",@"device",@"platform",@"app_version",@"uid"]
 birthday 格式 YYYY-MM-dd
 */
- (void)setUserId:(NSInteger )userId withToken:(NSString *)token;
- (void)setUserId:(NSInteger )userId  withProperties:( NSDictionary * _Nullable )userProperties andToken:(NSString *)token;

/*
 增量 更新 userProperties
 */
- (void)updateUserProperties:(NSDictionary *)userProperties;

/*
 打点
 */
- (void)logEvent:(NSString *)eventName;
- (void)logEvent:(NSString *)eventName  withEventProperties:(NSDictionary * _Nullable)attributes;

- (void)logEvent:(NSString *)eventName  withEventProperties:(NSDictionary * _Nullable)attributes andUserProperties:( NSDictionary * _Nullable)userSpecialProperties;
/**
 每次随机UID
 **/
+ (NSString *)randomUUID;

+ (NSString *)device_id;
/**
 获取唯一不变的id
 **/
+ (NSString *)keychain_id;
@end
