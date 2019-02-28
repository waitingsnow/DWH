//
//  DWHEventId.h
//  DWHSDK
//
//  Created by mao PengLin on 2018/7/2.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DWHEventId : NSObject
@property (nonatomic, copy) NSString *autoIncrementId;
@property (nonatomic, assign) long long at;
@end
