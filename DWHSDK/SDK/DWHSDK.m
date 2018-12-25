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
static NSInteger minDelayUploadEvent  = 1;
static NSInteger maxDelayUploadEvent  = 5;
@interface DWHSDK()

@property (nonatomic, strong) NSMutableDictionary *userProperties;
@property (nonatomic, strong) NSOperationQueue *backgroundQueue;
@property (nonatomic, assign) NSInteger failureCount;
@property (nonatomic, assign) BOOL isStopUsingDataWarehouse;
@property (nonatomic, assign) BOOL isUploadingEventNow;
@property (nonatomic, assign) BOOL showLog;

@property (nonatomic, assign) NSInteger userId;
@property (nonatomic, assign) NSInteger projectID;
@property (nonatomic, copy) NSString *auth;
@property (nonatomic, copy) NSString *currentSessionId;
@property (nonatomic, assign) DWHSDKLogLevel dwhLogLevel;
@property (nonatomic, assign) long long appStartTime;
@property (nonatomic, assign) long long serverStandardTime;
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
    NSArray *arr =   [DWHEventId dWHQueryForObjectArray:[NSString stringWithFormat:@"select autoIncrementId,at from DWHEventModel  where fullTime = 0"]];
    for (DWHEventId * model in arr) {
        long long time = [[NSProcessInfo processInfo] systemUptime]*1000 - model.at;
        if (time < 0) {
            time = 0;
        }
        [DWHEventModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
            [db dWHExecUpdate:[NSString stringWithFormat:@"update  DWHEventModel set at = %lld,fullTime = 1 where autoIncrementId = %@",self.serverStandardTime-time,model.autoIncrementId]];
        }];
    }
}
- (void)initializeProjectId:(NSInteger )projectId isProductionEnv:(BOOL)isProduction{
    self.projectID = projectId;
    self.auth = @"";
    [HWClient setEnv:isProduction];
    self.showLog = !isProduction;
    NSString *dbPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject];
    dbPath = [dbPath stringByAppendingPathComponent:@"/dwh5.db"];
    [DWHORMDB configDBPath:dbPath showLog:self.showLog];
    [DWHEventModel dWHCreateTable];
}
#pragma mark 启动sdk 获取auth
- (void)setUserId:(NSInteger )userId  withToken:(NSString *)token{
    [self setUserId:userId withProperties:nil andToken:token];
}

- (void)setUserId:(NSInteger )userId withProperties:(NSDictionary *)userProperties andToken:(NSString *)token{
    if (userProperties == nil) {
        self.userProperties = [[NSMutableDictionary alloc] init];
    }else {
        self.userProperties = [userProperties mutableCopy];
    }
    _userId = userId;
    if(self.isStopUsingDataWarehouse){
        if (DWHSDKLogLevelWarning >= self.dwhLogLevel) {
            NSLog(@"DWHSDK ----------> warning log sdk已暂停");
        }
        return ;
    }
    if(!self.projectID){
        if (DWHSDKLogLevelError >= self.dwhLogLevel) {
             NSLog(@"DWHSDK ----------> error log 没有设置projectID");
        }
        return;
    }
    if (userId!=0 && token.length) {
        
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
        
        self.auth = [NSString stringWithFormat:@"%@",token];
        if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
            NSLog(@"DWHSDK ----------> info log userId设置成功已经拿到auth");
        }
        [DWHEventModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
            [db dWHExecUpdate:[NSString stringWithFormat:@"update DWHEventModel set auth ='%@' where auth is null or trim(auth)='' ",self.auth]];
        }];
        [self runOnBackgroundQueue:^{
            [self checkToUploadEvent];
        }];
    
    }else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkToUploadEvent) object:nil];
        self.auth = @"";
    }
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _backgroundQueue = [[NSOperationQueue alloc] init];
        [_backgroundQueue setMaxConcurrentOperationCount:1];
        _backgroundQueue.name = BACKGROUND_QUEUE_NAME;
        self.currentSessionId = [DWHSDK randomUUID];
        self.dwhLogLevel = DWHSDKLogLevelNone;
        self.appStartTime = (long long)[[NSProcessInfo processInfo] systemUptime];
    }
    return self;
}

- (void)generateNewSessionId{
    [self runOnBackgroundQueue:^{
        self.currentSessionId = [DWHSDK randomUUID];
    }];
}
- (BOOL)runOnBackgroundQueue:(void (^)(void))block{
    if ([[NSOperationQueue currentQueue].name isEqualToString:BACKGROUND_QUEUE_NAME]) {
        //        NSLog(@"Already running in the background.");
        block();
        return NO;
    } else {
        [_backgroundQueue addOperationWithBlock:block];
        return YES;
    }
}
- (void)updateUserProperties:(NSDictionary *)userProperties{
    if(self.isStopUsingDataWarehouse){
        return ;
    }
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
    if(self.isStopUsingDataWarehouse){
        return ;
    }
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
    
    event.auth = self.auth;
    event.device_id = [DWHSDK keychain_id];
    
    NSMutableDictionary *userAttribute = [[NSMutableDictionary alloc] init];
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
        [event dWHSave:nil];
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
    NSMutableDictionary * dic = [DWHEventModel dWHQueryForDictionary:@"select * from  DWHEventModel where auth is not null and trim(auth) !=''  and fullTime = 1 order by autoIncrementId desc  limit 1 OFFSET 1"];
    
    if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
        NSLog(@"DWHSDK ----------> info log 5秒轮询 未上传的event");
    }
    if (dic && dic[@"at"]) {
        long long  at = [dic[@"at"] longLongValue];
        if (llabs([self curentTime] - at) >= 30*1000) {
            if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
                NSLog(@"DWHSDK ----------> info log 有超过30秒未上传的event");
            }
            NSString *auth = [NSString stringWithFormat:@"%@",dic[@"auth"]];
            NSMutableArray *uploadArr = [self getEventByAuth:auth];
            NSArray *arrId = [self getEventIdByAuth:auth];
            [self uploadEventToServer:uploadArr.copy auth:auth completeBlock:^(BOOL success) {
                if (success) {
                    [self clearEventById:arrId];
                }
                [self delayCheckToUploadEvent:success?minDelayUploadEvent:maxDelayUploadEvent];
            }];
            return;
        }
    }
    
    NSMutableDictionary * countDic = [DWHEventModel dWHQueryForDictionary:@"select count(*) as count from DWHEventModel where auth is not null and trim(auth) !='' and fullTime = 1"];
    if (self.showLog) {
        //        NSLog(@"轮询检测event 10条 :%@",countDic);
    }
    if (countDic && countDic[@"count"]) {
        int rowCount = [countDic[@"count"] intValue];
        if (rowCount >= 10) {
            if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
                NSLog(@"DWHSDK ----------> info log 有超过10条未上传的event");
            }
            NSMutableDictionary * authDic = [DWHEventModel dWHQueryForDictionary:@"select auth from DWHEventModel where auth is not null and trim(auth) !='' and fullTime = 1  limit 1"];
            //            NSLog(@"authDic:%@",authDic);
            if (authDic && authDic[@"auth"]) {
                NSString *auth = [NSString stringWithFormat:@"%@",authDic[@"auth"]];
                NSMutableArray *uploadArr = [self getEventByAuth:auth];
                NSArray *arrId = [self getEventIdByAuth:auth];
                [self uploadEventToServer:uploadArr.copy auth:auth completeBlock:^(BOOL success) {
                    if (success) {
                        [self clearEventById:arrId];
                    }
                    [self delayCheckToUploadEvent:success?minDelayUploadEvent:maxDelayUploadEvent];
                }];
                return;
            }
            
        }
    }
    
    NSMutableDictionary * lastOne = [DWHEventModel dWHQueryForDictionary:@"select * from  DWHEventModel where auth is not null and trim(auth) !='' and fullTime = 1 order by autoIncrementId desc  limit 1"];
    if (self.showLog) {
        //        NSLog(@"轮询检测event 最后一条 :%@",lastOne);
    }
    if (lastOne && lastOne[@"at"]) {
        long long  at = [lastOne[@"at"] longLongValue];
        if (llabs([self curentTime] - at) >= 30*1000) {
            if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
                NSLog(@"DWHSDK ----------> info log 有超过30秒未上传的打点");
            }
            NSString *auth = [NSString stringWithFormat:@"%@",lastOne[@"auth"]];
            NSMutableArray *uploadArr = [self getEventByAuth:auth];
            NSArray *arrId = [self getEventIdByAuth:auth];
            [self uploadEventToServer:uploadArr.copy auth:auth completeBlock:^(BOOL success) {
                if (success) {
                    [self clearEventById:arrId];
                }
                [self delayCheckToUploadEvent:success?minDelayUploadEvent:maxDelayUploadEvent];
            }];
            return;
        }
    }
    [self delayCheckToUploadEvent:maxDelayUploadEvent];
}
- (void)delayCheckToUploadEvent:(NSInteger)delay{
    if(self.isStopUsingDataWarehouse){
        return ;
    }
    if (self.isUploadingEventNow) {
        return;
    }
    __block __weak DWHSDK *weakSelf = self;
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
}
- (NSArray *)getEventIdByAuth:(NSString *)auth{
    NSArray *arr =   [DWHEventId dWHQueryForObjectArray:[NSString stringWithFormat:@"select autoIncrementId from DWHEventModel where auth = '%@' and fullTime = 1  limit 10",auth]];
    NSMutableArray *uploadArr = [[NSMutableArray alloc] init];
    for(DWHEventId *eventId in arr){
        [uploadArr addObject:eventId.autoIncrementId];
    }
    return uploadArr.copy;
}
- (NSMutableArray *)getEventByAuth:(NSString *)auth{
    NSArray *arr = [DWHEventModel dWHQueryForObjectArray:[NSString stringWithFormat:@"select * from DWHEventModel where auth = '%@' and fullTime = 1 limit 10",auth]];
    NSMutableArray *uploadArr = [[NSMutableArray alloc] init];
    for (DWHEventModel *model in arr) {
        NSLog(@"model:%@",model.session_id);
        NSMutableDictionary *uploadPar = [[NSMutableDictionary alloc] init];
        [uploadPar setValue:model.eventName forKey:@"event"];
        [uploadPar setValue:@(model.at) forKey:@"event_ts"];
        [uploadPar setValue:@"client" forKey:@"log_source"];
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
    NSLog(@"uploadArr:%@",uploadArr);
    return uploadArr;
}
- (void)uploadEventToServer:(NSArray *)events auth:(NSString *)auth completeBlock:(UploadCompleteBlock)block{
    if (!events || events.count == 0 || !auth || !auth.length ) {
        if (block) {
            block(FALSE);
        }
        return ;
    }
    self.isUploadingEventNow = YES;
    if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
        NSLog(@"DWHSDK ----------> info log 上传打点:%@",@{@"events":events});
    }
    [HWClient postToPath:@"v2/event" withParameters:@{@"events":events} auth:auth completeBlock:^(BOOL success, id result) {
        self.isUploadingEventNow = FALSE;
        if (self.showLog) {
            //             NSLog(@"DWH 上传结果:%i",success);
        }
        if (block) {
            block(success);
        }
        if(!success && [result intValue] >= 500){
            self.failureCount = self.failureCount +1;
            if (DWHSDKLogLevelError >= self.dwhLogLevel) {
                NSLog(@"DWHSDK ----------> error log 打点上传发生500以上的错误:%@ 失败次数:%li",result,self.failureCount);
            }
        }
        if((!success && [result intValue] == 404) || (!success && [result intValue] == 410)){
            self.failureCount = self.failureCount +1;
            if (DWHSDKLogLevelError >= self.dwhLogLevel) {
                NSLog(@"DWHSDK ----------> error log 打点上传发生410 404 的错误:%@ 失败次数:%li",result,self.failureCount);
            }
        }
        if (self.failureCount > 3) {
            [[NSUserDefaults standardUserDefaults] setValue:@"1" forKey:[NSString stringWithFormat:@"%@%@",StopUsingDataWarehouse,[[NSBundle mainBundle].infoDictionary objectForKey:@"CFBundleShortVersionString"]]];
            if (DWHSDKLogLevelError >= self.dwhLogLevel) {
                NSLog(@"DWHSDK ----------> error log DWH sdk 失败次数过多已经暂停访问");
            }
        }
        if (!success && [result integerValue] == 401) {
            [self handleHTTP401Error:auth];
        }
    }];
}
- (void)handleHTTP401Error:(NSString *)auth{
    [DWHEventModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
        [db dWHExecUpdate:[NSString stringWithFormat:@"update DWHEventModel set auth ='' where auth ='%@' ",auth]];
    }];
    [self setUserId:self.userId withProperties:self.userProperties andToken:auth];
    if (DWHSDKLogLevelError >= self.dwhLogLevel) {
        NSLog(@"DWHSDK ----------> error log 打点上传发生401错误,重置auth");
    }
}

- (long long)curentTime{
    return  [[NSDate date] timeIntervalSince1970]*1000;
}
- (BOOL)isStopUsingDataWarehouse{
    BOOL resuslt =  [[NSUserDefaults standardUserDefaults] valueForKey:[NSString stringWithFormat:@"%@%@",StopUsingDataWarehouse,[[NSBundle mainBundle].infoDictionary objectForKey:@"CFBundleShortVersionString"]]]!=nil;
    if (self.showLog && resuslt) {
        NSLog(@"dwh 已经暂停");
    }
    return resuslt;
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
    BOOL on = [[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
    NSString *uuidString = @"";
    if (on) {
        uuidString =  [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    }
    if (uuidString.length < 10) {
        NSString *key = [[UICKeyChainStore keyChainStore] stringForKey:@"DWHAPPDeviceID"];
        if (key.length) {
            return key;
        }else{
            CFUUIDRef uuid;
            CFStringRef uuidStr;
            uuid = CFUUIDCreate(NULL);
            uuidStr = CFUUIDCreateString(NULL, uuid);
            uuidString =[NSString stringWithFormat:@"%@-%lld",uuidStr,(long long)[[NSDate date] timeIntervalSince1970]];
            CFRelease(uuidStr);
            CFRelease(uuid);
            NSString *md5 = [[[uuidString dataUsingEncoding:NSUTF8StringEncoding] md5String] uppercaseString];
            [[UICKeyChainStore keyChainStore] setString:md5 forKey:@"DWHAPPDeviceID"];
            return md5;
        }
    }else{
        return uuidString;
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
        return key;
    }
    BOOL on = [[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
    NSString *uuidString = @"";
    if (on) {
        uuidString = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    }
    if (uuidString.length < 10) {
        CFUUIDRef uuid;
        CFStringRef uuidStr;
        uuid = CFUUIDCreate(NULL);
        uuidStr = CFUUIDCreateString(NULL, uuid);
        uuidString =[NSString stringWithFormat:@"%@-%lld",uuidStr,(long long)[[NSDate date] timeIntervalSince1970]];
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
    return @"1.1.3";
}
@end
