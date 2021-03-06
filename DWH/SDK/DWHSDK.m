//
//  DWHSDK.m
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/27.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import "DWHSDK.h"
#import "DWHNSObject+ORM.h"
#import "DWHORMDB.h"
#import "HWClient.h"
#import "DWHEventModel.h"
#import "NSString+Extension.h"
#import "NSDictionary+Extension.h"
#import "DWHSDKTool.h"
#import "DWHEventId.h"
#import <AdSupport/AdSupport.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import "NSData+DWHAdd.h"
#import <UIKit/UIKit.h>
typedef void (^UploadCompleteBlock)(BOOL success);
static NSInteger minDelayUploadEvent  = 3;
static NSInteger maxDelayUploadEvent  = 5;

#ifndef weakify
#if DEBUG
#if __has_feature(objc_arc)
#define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif

#ifndef strongify
#if DEBUG
#if __has_feature(objc_arc)
#define strongify(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) autoreleasepool{} __typeof__(object) object = block##_##object;
#endif
#else
#if __has_feature(objc_arc)
#define strongify(object) try{} @finally{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) try{} @finally{} __typeof__(object) object = block##_##object;
#endif
#endif
#endif

@interface DWHSDK(){
     UIBackgroundTaskIdentifier _backgroundTaskIdentifier;
}

@property (nonatomic, strong) NSMutableDictionary *userProperties;
@property (nonatomic, strong) NSOperationQueue *backgroundQueue;
@property (nonatomic, assign) BOOL isUploadingEventNow;
@property (nonatomic, assign) BOOL showLog;

@property (nonatomic, assign) NSInteger userId;
@property (nonatomic, assign) NSInteger projectID;
@property (nonatomic, copy) NSString *currentSessionId;
@property (nonatomic, assign) DWHSDKLogLevel dwhLogLevel;
@property (nonatomic, assign) long long appStartTime;
@property (nonatomic, assign) long long serverStandardTime;

@property (nonatomic, assign) int autoGrowthId;
@property (nonatomic, assign) NSInteger maxUploadTime;
@property (nonatomic, assign) NSInteger requestServerTimeCount;
@end

static NSString *const BACKGROUND_QUEUE_NAME = @"DWHBACKGROUND";

@implementation DWHSDK

+(instancetype)dwhSDK{
    static DWHSDK *_modelManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _modelManager = [[self alloc] init];
    });
    return _modelManager;
}
- (void)setLogLevel:(DWHSDKLogLevel)logLevel{
    self.dwhLogLevel = logLevel;
}
- (void)appDidFinishLaunch{
    self.appStartTime = [[NSProcessInfo processInfo] systemUptime];
}
- (void)setServerTime:(long long)serverTime{
    self.serverStandardTime = serverTime;
    self.appStartTime = [[NSProcessInfo processInfo] systemUptime];
    if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
        NSLog(@"DWHSDK ----------> 设置服务器时间:%lld",self.serverStandardTime);
    }
    NSArray *arr =   [DWHEventId dWHQueryForObjectArray:[NSString stringWithFormat:@"select autoIncrementId,at,localTime from DWHEventModel  where fullTime = 0"]];
    long long nowTime = [[NSDate date] timeIntervalSince1970]*1000;
    long long nowDifferenceForServerTime = nowTime-serverTime;//设置服务器时间的时候，本地时间和服务器时间的差多少毫秒
   
    for (DWHEventId * model in arr) {
        long long time = [[NSProcessInfo processInfo] systemUptime]*1000 - model.at;
        if (time < 0) {
            long long targetTime = serverTime;
            if (model.localTime) {
                targetTime = model.localTime-nowDifferenceForServerTime;
            }
            
            [DWHEventModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
                    [db dWHExecUpdate:[NSString stringWithFormat:@"update  DWHEventModel set at = %lld,fullTime = 1 where autoIncrementId = %@",targetTime,model.autoIncrementId]];
            }];
            
        }else{
            [DWHEventModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
                [db dWHExecUpdate:[NSString stringWithFormat:@"update  DWHEventModel set at = %lld,fullTime = 1 where autoIncrementId = %@",self.serverStandardTime-time,model.autoIncrementId]];
            }];
        }
    }
}
- (void)initializeProjectId:(NSInteger )projectId isProductionEnv:(BOOL)isProduction{
    self.projectID = projectId;
    [HWClient setEnv:isProduction];
    self.showLog = !isProduction;
    NSString *dbPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject];
    dbPath = [dbPath stringByAppendingPathComponent:@"/dwhEvent1.db"];
    [DWHORMDB configDBPath:dbPath showLog:self.showLog];
    [DWHEventModel dWHCreateTable];
    self.requestServerTimeCount = 0;
    [self updateServerTime];

}
- (void)updateServerTime{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateServerTime) object:nil];
    self.requestServerTimeCount += 1;
    [HWClient getToPath:@"timestamp" withParameters:nil auth:nil
           completeBlock:^(BOOL success, id result) {
               if (success && result && [result isKindOfClass:[NSDictionary class]]) {
                   NSDictionary *dic = (NSDictionary *)result;
                   if (dic.count) {
                     long long time =  [dic[@"timestamp"] longLongValue];
                       [self setServerTime:time];
                   }else{
                       if(self.requestServerTimeCount > 3){
                           long long time = [self curentTime];
                           [self setServerTime:time];
                       }else{
                           [self performSelector:@selector(updateServerTime) withObject:nil afterDelay:self.requestServerTimeCount>3?8:4];
                       }
                   }
               }else{
                   if(self.requestServerTimeCount > 3){
                       long long time = [self curentTime];
                       [self setServerTime:time];
                   }else{
                       [self performSelector:@selector(updateServerTime) withObject:nil afterDelay:self.requestServerTimeCount>2?8:4];
                   }
               }
           }];
}
#pragma mark 启动sdk 获取auth
- (void)setUserId:(NSInteger )userId{
    [self setUserId:userId withProperties:nil];
}

- (void)setUserId:(NSInteger )userId withProperties:(NSDictionary *)userProperties{
    if (userProperties == nil) {
        self.userProperties = [[NSMutableDictionary alloc] init];
    }else {
        self.userProperties = [userProperties mutableCopy];
    }
    _userId = userId;
    
    if(!self.projectID){
        if (DWHSDKLogLevelError >= self.dwhLogLevel) {
             NSLog(@"DWHSDK ----------> error log 没有设置projectID");
        }
        return;
    }
    if (userId!=0) {
        
        NSString *birthday = [NSString stringWithFormat:@"%@",self.userProperties[@"birthday"]];
        if (birthday.length > 10) {
            birthday = [birthday substringToIndex:10];
            [self.userProperties setValue:birthday forKey:@"birthday"];
        }
        [self.userProperties setValue:@(UserTimeZoneToUTC()) forKey:@"timezone"];
        [self.userProperties setValue:[NSString stringWithFormat:@"%@",[DWHSDKTool userDeviceLanguage]] forKey:@"device_language"];
        [self.userProperties setValue:[NSString stringWithFormat:@"%@",[DWHSDKTool userDeviceName]] forKey:@"device"];
        [self.userProperties setValue:[NSString stringWithFormat:@"%@",[DWHSDK clientVersion]] forKey:@"app_version"];
        [self.userProperties setValue:@(userId) forKey:@"uid"];
        
        NSMutableDictionary *mudic = [[NSMutableDictionary alloc] init];
        [mudic setValue:@(self.projectID) forKey:@"projectId"];
        [mudic setValue:@(userId) forKey:@"uid"];
        [mudic setValue:[NSString stringWithFormat:@"%@",[DWHSDK clientVersion]] forKey:@"version"];
        [mudic setValue:self.userProperties forKey:@"attributes"];
        
        
        if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
            NSLog(@"DWHSDK ----------> info log userId设置成功已经拿到auth");
        }
        
        [self runOnBackgroundQueue:^{
            [self checkToUploadEvent];
        }];
    
    }else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkToUploadEvent) object:nil];
    }
}

- (instancetype)init{
    self = [super init];
    if (self) {
        self.maxUploadTime = 30;
        _backgroundQueue = [[NSOperationQueue alloc] init];
        [_backgroundQueue setMaxConcurrentOperationCount:1];
        _backgroundQueue.name = BACKGROUND_QUEUE_NAME;
        self.currentSessionId = [DWHSDK randomUUID];
        self.autoGrowthId = 1;
        self.dwhLogLevel = DWHSDKLogLevelNone;
        self.appStartTime = (long long)[[NSProcessInfo processInfo] systemUptime];
        _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)generateNewSessionId{
    if (_backgroundTaskIdentifier == UIBackgroundTaskInvalid){
        UIApplication *application = [UIApplication sharedApplication];
        @weakify(self);
        _backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
            @strongify(self);
            [self endBackgroundTask];
        }];
    }
    self.maxUploadTime = 0;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(delayCheckToUploadEvent:) object:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimeInterval remainingTime =  [[UIApplication sharedApplication] backgroundTimeRemaining];
        [self performSelector:@selector(endBackgroundTask) withObject:nil afterDelay:MAX(remainingTime-0.1, 0)];
    });
    
    
    [self runOnBackgroundQueue:^{
        self.currentSessionId = [DWHSDK randomUUID];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSTimeInterval remainingTime =  [[UIApplication sharedApplication] backgroundTimeRemaining];
            if(remainingTime>5){
                [self delayCheckToUploadEvent:0];
            }
        });
    }];
   
}
- (BOOL)runOnBackgroundQueue:(void (^)(void))block{
    if ([[NSOperationQueue currentQueue].name isEqualToString:BACKGROUND_QUEUE_NAME]) {
        block();
        return NO;
    } else {
        [_backgroundQueue addOperationWithBlock:block];
        return YES;
    }
}
- (void)updateUserProperties:(NSDictionary *)userProperties{
   
    NSMutableDictionary *tmpDic = [userProperties mutableCopy];
    for (NSString *key in tmpDic){
        NSString *value = tmpDic[key];
        if ([key isEqualToString:@"birthday"]) {
            if (value.length > 10) {
                value = [value substringToIndex:10];
            }
        }
        [self.userProperties setValue:value forKey:key];
    }
}


- (void)logEvent:(NSString *)eventName {
    [self logEvent:eventName withEventProperties:@{}];
}
- (void)logEvent:(NSString *)eventName  withEventProperties:(NSDictionary * _Nullable)attributes andUserProperties:( NSDictionary * _Nullable)userSpecialProperties{
    
    DWHEventModel *event = [[DWHEventModel alloc] init];
    event.eventName = eventName;
    event.occurTime = [[NSProcessInfo processInfo] systemUptime];
    if (self.serverStandardTime == 0) {
        event.at =  [[NSProcessInfo processInfo] systemUptime]*1000;
        event.fullTime = 0;
    }else{
        long long seconds  = ([[NSProcessInfo processInfo] systemUptime]-self.appStartTime)*1000;
        event.fullTime = 1;
        event.at = self.serverStandardTime+seconds;
    }
    event.localTime = [[NSDate date] timeIntervalSince1970]*1000;
    if (self.autoGrowthId > 500) {
        self.autoGrowthId = 1;
    }
    event.autoGrowthID = self.autoGrowthId;
    self.autoGrowthId = self.autoGrowthId + 1;
    event.device_id = [DWHSDK keychain_id];
    
    NSMutableDictionary *userAttribute = [[NSMutableDictionary alloc] init];
    if (self.userProperties && self.userProperties.count) {
        [userAttribute addEntriesFromDictionary:self.userProperties];
    }
    if (userSpecialProperties) {
        [userAttribute addEntriesFromDictionary:userSpecialProperties];
    }
    //外部传入uid 或者user_id
    if(self.userProperties[@"uid"]){
        event.uid = [NSString stringWithFormat:@"%@",self.userProperties[@"uid"]];
    }
    if(self.userProperties[@"user_id"]){
        event.uid = [NSString stringWithFormat:@"%@",self.userProperties[@"user_id"]];
    }
    
    if(self.userProperties[@"age"]){
        [userAttribute setValue:[NSString stringWithFormat:@"%i",[self.userProperties[@"age"] intValue]] forKey:@"age"];
    }
    
    if(self.userProperties[@"gender"]){
        [userAttribute setValue:[[NSString stringWithFormat:@"%@",self.userProperties[@"gender"]] uppercaseString] forKey:@"gender"];
    }
    if (self.userProperties[@"account_create_ts"]) {
        [userAttribute setValue:[[NSString stringWithFormat:@"%@",self.userProperties[@"account_create_ts"]] uppercaseString] forKey:@"account_create_ts"];
    }
  
    if(self.userProperties[@"country"]){
        [userAttribute setValue:[NSString stringWithFormat:@"%@",self.userProperties[@"country"]] forKey:@"country"];
    }
    if(self.userProperties[@"region"]){
        [userAttribute setValue:[NSString stringWithFormat:@"%@",self.userProperties[@"region"]] forKey:@"region"];
    }
    if (self.userProperties[@"city"]) {
        [userAttribute setValue:[NSString stringWithFormat:@"%@",self.userProperties[@"city"]] forKey:@"city"];
    }
    [userAttribute setValue:[NSString stringWithFormat:@"%@",[DWHSDK clientVersion]] forKey:@"app_version"];
    
    if(self.userProperties[@"rvc_ban_status"]){
        [userAttribute setValue:[NSString stringWithFormat:@"%@",self.userProperties[@"rvc_ban_status"]] forKey:@"rvc_ban_status"];
    }
    if(self.userProperties[@"longitude"]){
        [userAttribute setValue:[NSString stringWithFormat:@"%@",self.userProperties[@"longitude"]] forKey:@"longitude"];
    }
    if(self.userProperties[@"latitude"]){
        [userAttribute setValue:[NSString stringWithFormat:@"%@",self.userProperties[@"latitude"]] forKey:@"latitude"];
    }
   
    [userAttribute setValue:[NSString stringWithFormat:@"%i",UserTimeZoneToUTC()] forKey:@"time_zone"];
    [userAttribute setValue:[DWHSDK sdkVersion] forKey:@"sdk_version"];
    [userAttribute setValue:[NSString stringWithFormat:@"%@",[[UIDevice currentDevice] systemVersion]] forKey:@"os_version"];
    [userAttribute setValue:@"iOS" forKey:@"os"];
    [userAttribute setValue:[NSString stringWithFormat:@"%@",[DWHSDKTool userDeviceName]] forKey:@"device"];
    [userAttribute setValue:[NSString stringWithFormat:@"%@",[DWHSDK idfa]] forKey:@"idfa"];
    [userAttribute setValue:[NSString stringWithFormat:@"%@",[[UIDevice currentDevice] identifierForVendor].UUIDString] forKey:@"idfv"];
    [userAttribute setValue:[NSString stringWithFormat:@"%@",[DWHSDK sdkVersion]] forKey:@"sdk_version"];
    [userAttribute setValue:[NSString stringWithFormat:@"%@",[DWHSDK keychain_id]] forKey:@"device_id"];
    NSString *preferredLanguage = [[NSLocale preferredLanguages] firstObject];
    if (preferredLanguage.length >= 2) {
        NSString *lan = [preferredLanguage substringToIndex:2];
        [userAttribute setValue:[NSString stringWithFormat:@"%@",lan] forKey:@"device_lang"];
    }
    
    if (!self.currentSessionId.length) {
        self.currentSessionId = [DWHSDK randomUUID];
    }
    event.session_id = self.currentSessionId;
    if (!attributes) {
        attributes = @{};
    }
    event.userProperties = [userAttribute toJSonString];
    event.attributes = [attributes toJSonString];
    __block __weak DWHSDK *weakSelf = self;
    [self runOnBackgroundQueue:^{
        if (event.fullTime == 1) {
             [event dWHSave:@[@"eventName",@"at"]];
        }else{
            [event dWHSave:nil];
        }
        if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
            NSLog(@"DWHSDK ----------> info log %@",attributes);
        }
        if (!weakSelf.isUploadingEventNow) {
            [weakSelf delayCheckToUploadEvent:maxDelayUploadEvent];
        }else{
            if (DWHSDKLogLevelWarning >= self.dwhLogLevel) {
                NSLog(@"DWHSDK ----------> warning log DWHSDK 已经暂停");
            }
        }
    }];
}

- (void)logEvent:(NSString *)eventName withEventProperties:(NSDictionary *)attributes{
    [self logEvent:eventName withEventProperties:attributes andUserProperties:nil];
}

/**
 检查是否可用将点 上传服务器
 1,当前时间大于event的触发时间 30s
 2,总记录数超过10条
 */
#pragma mark 打点上传服务器
- (void)checkToUploadEvent{
    if (self.isUploadingEventNow) {
        return;
    }
    
    NSMutableDictionary * dic =  [DWHEventModel dWHQueryForDictionary:@"select * from  DWHEventModel where fullTime = 1 order by autoIncrementId   limit 1"];
    
    if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
        NSLog(@"DWHSDK ----------> info log 5秒轮询 未上传的event");
    }
   
    
    if (dic && dic[@"at"]) {
        long long  at = [dic[@"at"] longLongValue];
        if (llabs([self curentTime] - at) >= self.maxUploadTime*1000) {
            if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
                NSLog(@"DWHSDK ----------> info log 有超过30秒未上传的event");
            }
            NSArray *eventArr = [self getEventByAuth];
            NSMutableArray *uploadArr = [self getUploadEvent:eventArr];
            NSArray *arrId = [self getEventIdByAuth];
            [self uploadEventToServer:uploadArr.copy auth:nil completeBlock:^(BOOL success) {
                if (success) {
                    [self clearEventById:arrId];
                    //服务器端存在相同事件点，根据上传点再次删除一次 看效果
                    [self clearEventByEvent:eventArr];
                }
                [self delayCheckToUploadEvent:success?minDelayUploadEvent:maxDelayUploadEvent];
            }];
            return;
        }
    }
    
    NSMutableDictionary * countDic = [DWHEventModel dWHQueryForDictionary:@"select count(*) as count from DWHEventModel where  fullTime = 1"];
    
    if (countDic && countDic[@"count"]) {
        int rowCount = [countDic[@"count"] intValue];
        if (rowCount >= 10) {
            if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
                NSLog(@"DWHSDK ----------> info log 有超过10条未上传的event");
            }
            
            NSArray *eventArr = [self getEventByAuth];
            NSMutableArray *uploadArr = [self getUploadEvent:eventArr];
            NSArray *arrId = [self getEventIdByAuth];
            [self uploadEventToServer:uploadArr.copy auth:nil completeBlock:^(BOOL success) {
                if (success) {
                    [self clearEventById:arrId];
                    [self clearEventByEvent:eventArr];
                }
                [self delayCheckToUploadEvent:success?minDelayUploadEvent:maxDelayUploadEvent];
            }];
            return;
        }
    }
    [self delayCheckToUploadEvent:maxDelayUploadEvent];
}
- (void)applicationDidBecomeActive:(NSNotification *)notification{
    [self endBackgroundTask];
    self.maxUploadTime = 30;
    [self checkHasLargeDataNotUpload];
}
- (void)checkHasLargeDataNotUpload{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkHasLargeDataNotUpload) object:nil];
    NSDictionary  *countDic =  [DWHEventModel dWHQueryForDictionary:@"select count(*) as count from DWHEventModel where  fullTime = 0"];
    if (countDic && countDic[@"count"]) {
        int rowCount = [countDic[@"count"] intValue];
        if (rowCount >= 100) {
            NSDate *date = [NSDate date];
            long long time = [date timeIntervalSince1970]*1000;
            [self setServerTime:time];
        }
    }
    
    NSDictionary  *totalDic =  [DWHEventModel dWHQueryForDictionary:@"select count(*) as count from DWHEventModel"];
    if (totalDic && totalDic[@"count"]) {
        int rowCount = [totalDic[@"count"] intValue];
        if (rowCount >= 100) {
            [self delayCheckToUploadEvent:0];
            [self performSelector:@selector(checkHasLargeDataNotUpload) withObject:nil afterDelay:6];
            return;
        }
    }
    [self performSelector:@selector(checkHasLargeDataNotUpload) withObject:nil afterDelay:20];
}

- (void)endBackgroundTask{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(endBackgroundTask) object:nil];
     UIApplication *application = [UIApplication sharedApplication];
    if (_backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [application endBackgroundTask:_backgroundTaskIdentifier];
        _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
}

- (void)delayCheckToUploadEvent:(NSTimeInterval)delay{
    if (self.isUploadingEventNow) {
        return;
    }
    __block __weak DWHSDK *weakSelf = self;
     [NSObject cancelPreviousPerformRequestsWithTarget:weakSelf selector:@selector(checkToUploadEvent) object:nil];
    [_backgroundQueue addOperationWithBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:weakSelf selector:@selector(checkToUploadEvent) object:nil];
            [weakSelf performSelector:@selector(checkToUploadEvent) withObject:nil afterDelay:delay];
        });
    }];
}
- (void)clearEventById:(NSArray *)arrayId{
    [DWHEventModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
        [db dWHExecDelete:[NSString stringWithFormat:@"delete from DWHEventModel where autoIncrementId in (%@)",[arrayId componentsJoinedByString:@","]]];
    }];
    [DWHEventModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
        for (NSString *aid in arrayId) {
            [db dWHExecDelete:[NSString stringWithFormat:@"delete from DWHEventModel where autoIncrementId = '%@'",aid]];
        }
    }];
}
- (void)clearEventByEvent:(NSArray *)arr{
    [DWHEventModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
        for (DWHEventModel *event in arr) {
            [db dWHExecDelete:[NSString stringWithFormat:@"delete from DWHEventModel where autoGrowthID = '%i' and eventName = '%@' and at = '%lld'",event.autoGrowthID,event.eventName,event.at]];
        }
    }];
}
- (NSArray *)getEventIdByAuth{
    NSArray *arr =  [DWHEventId dWHQueryForObjectArray:[NSString stringWithFormat:@"select autoIncrementId from DWHEventModel where  fullTime = 1  limit 10"]];
    
    NSMutableArray *uploadArr = [[NSMutableArray alloc] init];
    for(DWHEventId *eventId in arr){
        [uploadArr addObject:eventId.autoIncrementId];
    }
    return uploadArr.copy;
}
- (NSArray *)getEventByAuth{
    NSArray *arr = [DWHEventModel dWHQueryForObjectArray:@"select * from DWHEventModel where  fullTime = 1 order by autoIncrementId limit 10"];
        return arr;
    
}

- (NSMutableArray *)getUploadEvent:(NSArray *)arr{
    NSMutableArray *uploadArr = [[NSMutableArray alloc] init];
    for (DWHEventModel *model in arr) {
        NSMutableDictionary *uploadPar = [[NSMutableDictionary alloc] init];
        [uploadPar setValue:model.eventName forKey:@"event"];
        [uploadPar setValue:@(model.at) forKey:@"event_ts"];
        [uploadPar setValue:@"client" forKey:@"log_source"];
        [uploadPar setValue:@(model.autoGrowthID) forKey:@"loop_id"];
        [uploadPar setValue:[NSString stringWithFormat:@"%li",(long)self.projectID] forKey:@"app_id"];
        [uploadPar setValue:[DWHSDK data_version] forKey:@"data_version"];
        [uploadPar setValue:[NSString stringWithFormat:@"%@",model.session_id] forKey:@"session_id"];
        [uploadPar setValue:[NSString stringWithFormat:@"%@",model.uid] forKey:@"user_id"];
        if (self.serverStandardTime > 0) {
            long long seconds =([[NSProcessInfo processInfo] systemUptime]-self.appStartTime)*1000;
            long long upload_ts = self.serverStandardTime+seconds;
            [uploadPar setValue:@(upload_ts) forKey:@"event_upload_ts"];
        }else{
            long long seconds = ([[NSProcessInfo processInfo] systemUptime] - model.occurTime)*1000;
            long long upload_ts = model.at+seconds;
            [uploadPar setValue:@(upload_ts) forKey:@"event_upload_ts"];
        }
        
        NSDictionary *dic = [model.attributes toDictionary];
        [uploadPar setValue:dic forKey:@"attributes"];
        
        NSDictionary *att = [model.userProperties toDictionary];
        [uploadPar setValue:att forKey:@"user_properties"];
        [uploadArr addObject:uploadPar];
    }
//    NSLog(@"uploadArr:%@",uploadArr);
    return uploadArr;
}

- (void)uploadEventToServer:(NSArray *)events auth:(NSString *)auth completeBlock:(UploadCompleteBlock)block{
    if (!events || events.count == 0 ) {
        if (block) {
            block(FALSE);
        }
        return ;
    }
    self.isUploadingEventNow = YES;
    [HWClient postToPath:@"v2/event" withParameters:@{@"events":events} auth:auth completeBlock:^(BOOL success, id result) {
        self.isUploadingEventNow = FALSE;
        if (block) {
            block(success);
        }
    }];
}

- (long long)curentTime{
    return  [[NSDate date] timeIntervalSince1970]*1000;
}


+ (NSString *)idfa{
    BOOL on = [[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
    NSString *uuidString = @"";
    if (on) {
        uuidString =  [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    }
    return uuidString;
}
+ (NSString *)device_id{
    NSString *key = [[UICKeyChainStore keyChainStore] stringForKey:@"DWHAPPDeviceID"];
    if (key.length) {
        if(![key isEqualToString:@"9F89C84A559F573636A47FF8DAED0D33"]){
            return key;
        }
    }
    BOOL on = [[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
    NSString *uuidString = @"";
    if (on) {
        uuidString =  [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    }
    NSRange r = [uuidString rangeOfString:@"00000000"];
    if (r.location == 0 || r.location != NSNotFound) {
        uuidString = @"";
    }
    if (uuidString.length < 10) {
        CFUUIDRef uuid;
        CFStringRef uuidStr;
        uuid = CFUUIDCreate(NULL);
        uuidStr = CFUUIDCreateString(NULL, uuid);
        uuidString =[NSString stringWithFormat:@"%@-%lld",uuidStr,(long long)[[NSDate date] timeIntervalSince1970]*1000];
        CFRelease(uuidStr);
        CFRelease(uuid);
        NSString *md5 = [[[uuidString dataUsingEncoding:NSUTF8StringEncoding] md5String] uppercaseString];
        [[UICKeyChainStore keyChainStore] setString:md5 forKey:@"DWHAPPDeviceID"];
        return md5;
        
    }else{
        NSString *md5 = [[[uuidString dataUsingEncoding:NSUTF8StringEncoding] md5String] uppercaseString];
        [[UICKeyChainStore keyChainStore] setString:md5 forKey:@"DWHAPPDeviceID"];
        return md5;
    }
}
+ (NSString *)randomUUID{
    CFUUIDRef uuid;
    CFStringRef uuidStr;
    uuid = CFUUIDCreate(NULL);
    uuidStr = CFUUIDCreateString(NULL, uuid);
    NSString * uuidString =[NSString stringWithFormat:@"%@",uuidStr];
    CFRelease(uuidStr);
    CFRelease(uuid);
    return uuidString;
}
+ (NSString *)keychain_id{
    NSString *key = [[UICKeyChainStore keyChainStore] stringForKey:@"DWHAPPUID"];
    if (key) {
        if(![key isEqualToString:@"9F89C84A559F573636A47FF8DAED0D33"]){
            return key;
        }
    }
    BOOL on = [[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
    NSString *uuidString = @"";
    if (on) {
        uuidString = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    }
    NSRange r = [uuidString rangeOfString:@"00000000"];
     if (r.location == 0 || r.location != NSNotFound) {
        uuidString = @"";
    }
    if (uuidString.length < 10) {
        CFUUIDRef uuid;
        CFStringRef uuidStr;
        uuid = CFUUIDCreate(NULL);
        uuidStr = CFUUIDCreateString(NULL, uuid);
        uuidString =[NSString stringWithFormat:@"%@-%lld",uuidStr,(long long)[[NSDate date] timeIntervalSince1970]*1000];
        CFRelease(uuidStr);
        CFRelease(uuid);
    }
   NSString *md5 = [[[uuidString dataUsingEncoding:NSUTF8StringEncoding] md5String] uppercaseString];
    if (md5.length) {
        [[UICKeyChainStore keyChainStore] setString:md5 forKey:@"DWHAPPUID"];
    }
    return md5;
}
+ (NSString *)clientVersion{
    NSString *version = [[NSBundle mainBundle].infoDictionary objectForKey:@"CFBundleShortVersionString"];
    if (version) {
        return version;
    }
    return @"0.0.0";
}
+ (NSString *)data_version{
    return @"1.0";
}
+ (NSString *)sdkVersion{
    return @"1.4.0";
}
@end
