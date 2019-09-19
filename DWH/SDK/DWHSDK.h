//
//  DWHSDK.h
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/27.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum: NSUInteger {
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
- (void)setUserId:(NSInteger)userId;
- (void)setUserId:(NSInteger)userId withProperties:(NSDictionary * __nullable)userProperties;

/*
 增量 更新 userProperties
 */
- (void)updateUserProperties:(NSDictionary *)userProperties;
/**
 app 进入前台
 **/
- (void)generateNewSessionId;
/**
 app 启动，设置一个初始化的启动时间，处理没有设置服务器时间就打点的情况
 **/
- (void)appDidFinishLaunch;
/*
 打点
 */
- (void)logEvent:(NSString *)eventName;
- (void)logEvent:(NSString *)eventName withEventProperties:(NSDictionary * __nullable)attributes;

- (void)logEvent:(NSString *)eventName withEventProperties:(NSDictionary * __nullable)attributes andUserProperties:( NSDictionary * __nullable)userSpecialProperties;
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

NS_ASSUME_NONNULL_END
