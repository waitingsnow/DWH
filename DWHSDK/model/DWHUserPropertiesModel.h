//
//  DWHUserPropertiesModel.h
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/28.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DWHUserPropertiesModel : NSObject

@property (nonatomic, copy) NSString *auth;
@property (nonatomic, assign) NSInteger uid;
@property (nonatomic, copy) NSString *columnName;
@property (nonatomic, copy) NSString *columnValue;
@end
