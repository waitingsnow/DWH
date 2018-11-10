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
#import "DWHUserPropertiesModel.h"
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
- (void)setServerTime:(long long)serverTime{
    self.serverStandardTime = serverTime;
    self.appStartTime = [[NSProcessInfo processInfo] systemUptime];
    if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
        NSLog(@"DWHSDK ----------> 设置服务器时间:%lld",self.serverStandardTime);
    }
    [DWHEventModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
        [db dWHExecDelete:[NSString stringWithFormat:@"update  DWHEventModel set at = %lld where at = -1",serverTime]];
    }];
}
- (void)initializeProjectId:(NSInteger )projectId isProductionEnv:(BOOL)isProduction{
    self.projectID = projectId;
    self.auth = @"";
    [HWClient setEnv:isProduction];
    self.showLog = !isProduction;
    
    NSString *dbPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject];
    dbPath = [dbPath stringByAppendingPathComponent:@"/dwh.db"];
    [DWHORMDB configDBPath:dbPath showLog:self.showLog];
    [DWHEventModel dWHCreateTable];
    [DWHUserPropertiesModel dWHCreateTable];
}
#pragma mark 启动sdk 获取auth
- (void)setUserId:(NSInteger )userId {
    [self setUserId:userId withProperties:nil];
}

- (void)setUserId:(NSInteger )userId withProperties:(NSDictionary *)userProperties {
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
    if (userId!=0) {
        
        NSString *birthday = [NSString stringWithFormat:@"%@",self.userProperties[@"birthday"]];
        if (birthday.length > 10) {
            birthday = [birthday substringToIndex:10];
            [self.userProperties setValue:birthday forKey:@"birthday"];
        }
        [self.userProperties setValue:@(UserTimeZoneToUTC()) forKey:@"timezone"];
        [self.userProperties setValue:[NSString stringWithFormat:@"%@",[DWHSDKTool userDeviceLanguage]] forKey:@"device_language"];
        [self.userProperties setValue:[NSString stringWithFormat:@"%@",[DWHSDKTool userDeviceName]] forKey:@"device"];
        [self.userProperties setValue:@"iOS" forKey:@"platform"];
        [self.userProperties setValue:[NSString stringWithFormat:@"%@",[DWHSDK clientVersion]] forKey:@"app_version"];
        [self.userProperties setValue:@(userId) forKey:@"uid"];
        
        NSMutableDictionary *mudic = [[NSMutableDictionary alloc] init];
        [mudic setValue:@(self.projectID) forKey:@"projectId"];
        [mudic setValue:@(userId) forKey:@"uid"];
        [mudic setValue:[NSString stringWithFormat:@"%@",[DWHSDK clientVersion]] forKey:@"version"];
        [mudic setValue:self.userProperties forKey:@"attributes"];
        
        [HWClient putToPath:@"v1/user/session" withParameters:mudic auth:nil completeBlock:^(BOOL success, id result) {
            if (success && result && result[@"auth"]) {
                self.auth = [NSString stringWithFormat:@"%@",result[@"auth"]];
                if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
                    NSLog(@"DWHSDK ----------> info log userId设置成功已经拿到auth");
                }
                [DWHEventModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
                    [db dWHExecUpdate:[NSString stringWithFormat:@"update DWHEventModel set auth ='%@' where auth is null or trim(auth)='' ",self.auth]];
                }];
                [DWHUserPropertiesModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
                    [db dWHExecUpdate:[NSString stringWithFormat:@"update DWHUserPropertiesModel set auth ='%@' where (auth is null or trim(auth)='') and uid = '%li'",self.auth,(long)self.userId]];
                }];
                [self runOnBackgroundQueue:^{
                    [self checkToUploadUserPropertiesToServer];
                    [self checkToUploadEvent];
                }];
            }else{
                if([result intValue] >= 500){
                    self.failureCount = self.failureCount +1;
                }
                if([result intValue] == 404 || [result intValue] == 410){
                    self.failureCount = self.failureCount +1;
                }
                if (self.failureCount > 3) {
                    [[NSUserDefaults standardUserDefaults] setValue:@"1" forKey:[NSString stringWithFormat:@"%@%@",StopUsingDataWarehouse,[[NSBundle mainBundle].infoDictionary objectForKey:@"CFBundleShortVersionString"]]];
                }
                if (!success && [result integerValue] == 401) {
                    [self handleHTTP401Error:self.auth];
                }else{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self setUserId:self.userId withProperties:self.userProperties];
                    });
                }
            }
            
        }];
    }else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkToUploadUserPropertiesToServer) object:nil];
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
        NSLog(@"DWH-------------------->sessionid:%@ start time:%lld",self.currentSessionId,self.appStartTime);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive)
                                                     name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}
- (void)applicationWillResignActive{
    self.currentSessionId = [DWHSDK randomUUID];
    NSLog(@"DWH-------------------->new sessionid:%@",self.currentSessionId);
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
    __block __weak DWHSDK *weakSelf = self;
    NSMutableDictionary *tmpDic = [userProperties mutableCopy];
    [self runOnBackgroundQueue:^{
        if(tmpDic){
            for (NSString *key in tmpDic){
                NSString *value = tmpDic[key];
                DWHUserPropertiesModel *model = [[DWHUserPropertiesModel alloc] init];
                model.uid = weakSelf.userId;
                model.columnName = key;
                if ([key isEqualToString:@"birthday"]) {
                    if (value.length > 10) {
                        value = [value substringToIndex:10];
                    }
                }
                [weakSelf.userProperties setValue:value forKey:key];
                model.columnValue = [@{key:value} toJSonString];
                model.auth = weakSelf.auth;
                [model dWHSave:@[@"uid",@"columnName"]];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:weakSelf selector:@selector(checkToUploadUserPropertiesToServer) object:nil];
            [weakSelf performSelector:@selector(checkToUploadUserPropertiesToServer) withObject:nil afterDelay:5];
        });
    }];
}

/**
 检查是否有未上传的 user proerties
 **/
#pragma mark 用户属性 上传到服务器
- (void)checkToUploadUserPropertiesToServer{
    if(self.isStopUsingDataWarehouse){
        return ;
    }
    NSMutableDictionary *mudic = [DWHUserPropertiesModel dWHQueryForDictionary:@"select uid  from DWHUserPropertiesModel where auth is not null and trim(auth) !=''"];
   
    if (mudic && mudic[@"uid"]) {
        if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
            NSLog(@"DWHSDK ----------> info log 5秒轮询 检测上传 User properties 有数据准备上传");
        }
        NSString *uid = [NSString stringWithFormat:@"%@",mudic[@"uid"]];
        NSArray *properties = [DWHUserPropertiesModel dWHQueryForObjectArray:[NSString stringWithFormat:@"select * from DWHUserPropertiesModel where uid = '%@'",uid]];
        NSArray *arrayId = [DWHEventId dWHQueryForObjectArray:[NSString stringWithFormat:@"select autoIncrementId from DWHUserPropertiesModel where uid = '%@'",uid]];
        NSMutableArray *deleteId = [[NSMutableArray alloc] init];
        for(DWHEventId *eventId in arrayId){
            [deleteId addObject:eventId.autoIncrementId];
        }
        NSMutableDictionary *para = [[NSMutableDictionary alloc] init];
        NSString *auth = @"";
        for (DWHUserPropertiesModel *pName in properties) {
            NSDictionary *dic =   [pName.columnValue toDictionary];
            if (pName.auth) {
                auth = pName.auth;
            }
            if (dic && dic[pName.columnName]) {
                [para setValue:dic[pName.columnName] forKey:pName.columnName];
            }
        }
        if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
            NSLog(@"DWHSDK ----------> info log 上传 User properties:%@",para);
        }
        [HWClient putToPath:@"v1/user" withParameters:para auth:auth completeBlock:^(BOOL success, id result) {
            if (success) {
                [DWHUserPropertiesModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
                    [db dWHExecDelete:[NSString stringWithFormat:@"delete from DWHUserPropertiesModel where autoIncrementId in (%@)",[deleteId componentsJoinedByString:@","]]];
                }];
                if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
                    NSLog(@"DWHSDK ----------> info log  User properties 更新成功");
                }
            }else{
                if (DWHSDKLogLevelWarning >= self.dwhLogLevel) {
                    NSLog(@"DWHSDK ----------> warning log  User properties 更新失败");
                }
                if([result intValue] >= 500){
                    self.failureCount = self.failureCount +1;
                }
                if([result intValue] == 404 || [result intValue] == 410){
                    self.failureCount = self.failureCount +1;
                }
                if (self.failureCount > 3) {
                    [[NSUserDefaults standardUserDefaults] setValue:@"1" forKey:[NSString stringWithFormat:@"%@%@",StopUsingDataWarehouse,[[NSBundle mainBundle].infoDictionary objectForKey:@"CFBundleShortVersionString"]]];
                }
            }
            [self delayCheckToUploadUserPropertiesToServer];
            if (!success && [result integerValue] == 401) {
                [self handleHTTP401Error:auth];
            }
        }];
    }else{
        [self delayCheckToUploadUserPropertiesToServer];
    }
}
- (void)delayCheckToUploadUserPropertiesToServer{
    if(self.isStopUsingDataWarehouse){
        return ;
    }
    __block __weak DWHSDK *weakSelf = self;
    [_backgroundQueue addOperationWithBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:weakSelf selector:@selector(checkToUploadUserPropertiesToServer) object:nil];
            [weakSelf performSelector:@selector(checkToUploadUserPropertiesToServer) withObject:nil afterDelay:5];
        });
    }];
}

- (void)logEvent:(NSString *)eventName {
    [self logEvent:eventName withEventProperties:@{}];
}

- (void)logEvent:(NSString *)eventName withEventProperties:(NSDictionary *)attributes{
    if(self.isStopUsingDataWarehouse){
        return ;
    }
    DWHEventModel *event = [[DWHEventModel alloc] init];
    event.eventName = eventName;
    if (self.serverStandardTime == 0) {
         event.at = -1;
    }else{
        long long seconds = [[NSProcessInfo processInfo] systemUptime]-self.appStartTime;
        if (self.serverStandardTime > 100000000000) {
            seconds = ([[NSProcessInfo processInfo] systemUptime]-self.appStartTime)*1000;
        }
        event.at = self.serverStandardTime+seconds;
    }
   
    event.auth = self.auth;
    event.device_id = [DWHSDK device_id];
    event.keychain_id = [DWHSDK keychain_id];
    if(self.userProperties[@"uid"]){
        event.uid = [NSString stringWithFormat:@"%@",self.userProperties[@"uid"]];
    }
    if(self.userProperties[@"birthday"]){
        event.birthday = [NSString stringWithFormat:@"%@",self.userProperties[@"birthday"]];
    }
    if(self.userProperties[@"gender"]){
        event.gender = [NSString stringWithFormat:@"%@",self.userProperties[@"gender"]];
    }
    if(self.userProperties[@"nation"]){
        event.nation = [NSString stringWithFormat:@"%@",self.userProperties[@"nation"]];
    }
    if(self.userProperties[@"app_verison"]){
        event.app_verison = [NSString stringWithFormat:@"%@",self.userProperties[@"app_verison"]];
    }else{
        event.app_verison = [NSString stringWithFormat:@"%@",[DWHSDK clientVersion]];
    }
    if(self.userProperties[@"ban_status"]){
        event.ban_status = [NSString stringWithFormat:@"%@",self.userProperties[@"ban_status"]];
    }
    if(self.userProperties[@"longitude"]){
        event.longitude = [NSString stringWithFormat:@"%@",self.userProperties[@"longitude"]];
    }
    if(self.userProperties[@"latitude"]){
        event.latitude = [NSString stringWithFormat:@"%@",self.userProperties[@"latitude"]];
    }
    
    if (!self.currentSessionId.length) {
        self.currentSessionId = [DWHSDK randomUUID];
    }
    event.session_id = self.currentSessionId;
    if (!attributes) {
        attributes = @{};
    }
    
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
    NSMutableDictionary * dic = [DWHEventModel dWHQueryForDictionary:@"select * from  DWHEventModel where auth is not null and trim(auth) !=''  and at != -1 order by autoIncrementId desc  limit 1 OFFSET 1"];
    
    if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
        NSLog(@"DWHSDK ----------> info log 5秒轮询 未上传的event");
    }
    if (dic && dic[@"at"]) {
        long long  at = [dic[@"at"] longLongValue];
        if (llabs([self curentTime] - at) >= (30 * ((at > 100000000000)?1000:1))) {
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
    
    NSMutableDictionary * countDic = [DWHEventModel dWHQueryForDictionary:@"select count(*) as count from DWHEventModel where auth is not null and trim(auth) !='' and at != -1"];
    if (self.showLog) {
        //        NSLog(@"轮询检测event 10条 :%@",countDic);
    }
    if (countDic && countDic[@"count"]) {
        int rowCount = [countDic[@"count"] intValue];
        if (rowCount >= 10) {
            if (DWHSDKLogLevelInfo >= self.dwhLogLevel) {
                NSLog(@"DWHSDK ----------> info log 有超过10条未上传的event");
            }
            NSMutableDictionary * authDic = [DWHEventModel dWHQueryForDictionary:@"select auth from DWHEventModel where auth is not null and trim(auth) !='' and at != -1  limit 1"];
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
    
    NSMutableDictionary * lastOne = [DWHEventModel dWHQueryForDictionary:@"select * from  DWHEventModel where auth is not null and trim(auth) !='' and at != -1 order by autoIncrementId desc  limit 1"];
    if (self.showLog) {
        //        NSLog(@"轮询检测event 最后一条 :%@",lastOne);
    }
    if (lastOne && lastOne[@"at"]) {
        long long  at = [lastOne[@"at"] longLongValue];
        if (llabs([self curentTime] - at) >= (30 * ((at > 100000000000)?1000:1))) {
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
    NSArray *arr =   [DWHEventId dWHQueryForObjectArray:[NSString stringWithFormat:@"select autoIncrementId from DWHEventModel where auth = '%@' limit 10",auth]];
    NSMutableArray *uploadArr = [[NSMutableArray alloc] init];
    for(DWHEventId *eventId in arr){
        [uploadArr addObject:eventId.autoIncrementId];
    }
    return uploadArr.copy;
}
- (NSMutableArray *)getEventByAuth:(NSString *)auth{
    NSArray *arr = [DWHEventModel dWHQueryForObjectArray:[NSString stringWithFormat:@"select * from DWHEventModel where auth = '%@' limit 10",auth]];
    NSMutableArray *uploadArr = [[NSMutableArray alloc] init];
    for (DWHEventModel *model in arr) {
        NSMutableDictionary *uploadPar = [[NSMutableDictionary alloc] init];
        [uploadPar setValue:model.eventName forKey:@"eventName"];
        NSDictionary *dic = [model.attributes toDictionary];
        [uploadPar setValue:dic forKey:@"attributes"];
        [uploadPar setValue:@(model.at) forKey:@"at"];
        
        NSMutableDictionary *common = [[NSMutableDictionary alloc] init];
        if(model.uid.length){
            [common setValue:model.uid forKey:@"uid"];
        }
        [common setValue:@"iOS" forKey:@"platform"];
        if(model.birthday.length){
            [common setValue:model.birthday forKey:@"birthday"];
        }
        if(model.gender.length){
            [common setValue:model.gender forKey:@"gender"];
        }
        if(model.nation.length){
            [common setValue:model.nation forKey:@"nation"];
        }
        if(model.app_verison.length){
            [common setValue:model.app_verison forKey:@"app_verison"];
        }
        if(model.ban_status.length){
            [common setValue:model.ban_status forKey:@"ban_status"];
        }
        if(model.longitude.length){
            [common setValue:model.longitude forKey:@"longitude"];
        }
        if(model.latitude.length){
            [common setValue:model.latitude forKey:@"latitude"];
        }
        if(model.keychain_id.length){
            [common setValue:model.keychain_id forKey:@"keychain_id"];
        }else{
            [common setValue:[DWHSDK keychain_id]forKey:@"keychain_id"];
        }
        if(model.device_id.length){
             [common setValue:model.device_id forKey:@"device_id"];
        }else{
            [common setValue:[DWHSDK device_id] forKey:@"device_id"];
        }
        if(model.session_id.length){
            [common setValue:model.session_id forKey:@"session_id"];
        }
        [uploadPar setValue:common forKey:@"user_properties"];
        [uploadArr addObject:uploadPar];
    }
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
    [HWClient postToPath:@"v1/event" withParameters:@{@"events":events} auth:auth completeBlock:^(BOOL success, id result) {
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
    [DWHUserPropertiesModel dWHExecSql:^(DWHSqlOperationQueueObject *db) {
        [db dWHExecUpdate:[NSString stringWithFormat:@"update DWHUserPropertiesModel set auth ='' where auth =  '%@'",auth]];
    }];
    [self setUserId:self.userId withProperties:self.userProperties];
    if (DWHSDKLogLevelError >= self.dwhLogLevel) {
        NSLog(@"DWHSDK ----------> error log 打点上传发生401错误,重置auth");
    }
}

- (long long)curentTime{
    return  [[NSDate date] timeIntervalSince1970]*((self.serverStandardTime>100000000000)?1000:1);
}
- (BOOL)isStopUsingDataWarehouse{
    BOOL resuslt =  [[NSUserDefaults standardUserDefaults] valueForKey:[NSString stringWithFormat:@"%@%@",StopUsingDataWarehouse,[[NSBundle mainBundle].infoDictionary objectForKey:@"CFBundleShortVersionString"]]]!=nil;
    if (self.showLog && resuslt) {
        NSLog(@"dwh 已经暂停");
    }
    return resuslt;
}
+ (NSString *)sdkVersion{
    return @"0.69";
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
@end
