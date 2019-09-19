//
//  HWClient.h
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/27.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^EXUCompleteBlock)(BOOL success, id result);

static NSString *StopUsingDataWarehouse = @"StopUsingDataWarehouse";

@interface HWClient : NSObject

+ (void)setEnv:(BOOL)isProduction;

+ (void)putToPath:(NSString *)path
   withParameters:(NSDictionary * __nullable)parameters
             auth:(NSString * __nullable)auth
    completeBlock:(EXUCompleteBlock)complete;

+ (void)postToPath:(NSString *)path
    withParameters:(NSDictionary *)parameters
              auth:(NSString *)auth
     completeBlock:(EXUCompleteBlock)complete;

+ (void)getToPath:(NSString *)path
   withParameters:(NSDictionary * __nullable)parameters
			 auth:(NSString * __nullable)auth
	completeBlock:(EXUCompleteBlock)complete;

@end

NS_ASSUME_NONNULL_END
