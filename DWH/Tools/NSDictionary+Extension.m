//
//  NSDictionary+Extension.m
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/29.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import "NSDictionary+Extension.h"

@implementation NSDictionary(Extension)
- (NSString *)toJSonString{
    NSString *jsonString = @"";
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self
                                                       options:0
                                                         error:&error];
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}
@end
