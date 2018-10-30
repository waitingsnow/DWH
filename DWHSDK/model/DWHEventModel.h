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

@end