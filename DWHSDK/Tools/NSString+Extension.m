//
//  NSString+Extension.m
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/28.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import "NSString+Extension.h"

@implementation NSString(Extension)
- (NSDictionary *)toDictionary{
    NSDictionary *parameterInfo = nil;
    if ([self length]) {
        NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
        NSError *convertError = nil;
        NSDictionary *convertParameter = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&convertError];
        if ([convertParameter isKindOfClass:[NSDictionary class]] && [[convertParameter allKeys] count]) {
            parameterInfo = convertParameter;
        }
    }
    return parameterInfo;
}
@end
