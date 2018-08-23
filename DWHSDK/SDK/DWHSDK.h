//
//  DWHSDK.h
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/27.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DWHSDK : NSObject

+ (instancetype)dwhSDK;

+ (NSString *)sdkVersion;

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
- (void)setUserId:(NSInteger )userId;
- (void)setUserId:(NSInteger )userId withProperties:( NSDictionary * _Nullable )userProperties;

/*
 增量 更新 userProperties
 */
- (void)updateUserProperties:(NSDictionary *)userProperties;

/*
 打点
 */
- (void)logEvent:(NSString *)eventName;
- (void)logEvent:(NSString *)eventName  withEventProperties:(NSDictionary * _Nullable)attributes;

@end
