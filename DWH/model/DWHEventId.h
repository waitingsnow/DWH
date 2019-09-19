//
//  DWHEventId.h
//  DWHSDK
//
//  Created by mao PengLin on 2018/7/2.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DWHEventId : NSObject

@property (nonatomic, copy) NSString *autoIncrementId;
@property (nonatomic, assign) long long at;
@property (nonatomic, assign) long long localTime;

@end

NS_ASSUME_NONNULL_END
