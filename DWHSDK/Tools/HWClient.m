//
//  HWClient.m
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/27.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import "HWClient.h"
#import "DWHNSObject+ORM.h"

static NSString *apiUrl = @"";

@implementation HWClient
+ (void)setEnv:(BOOL)isProduction{
    if (isProduction) {
        apiUrl = @"https://dw-api.holla.world/";
    }else{
        apiUrl = @"http://dw-api-sandbox.holla.world/";
    }
}
+ (void)putToPath:(NSString *)path withParameters:(NSDictionary *)parameters auth:(NSString *)auth  completeBlock:(EXUCompleteBlock)complete{
    [self requestServer:path withParameters:parameters auth:auth method:@"PUT" completeBlock:complete];
}
+ (void)postToPath:(NSString *)path withParameters:(NSDictionary *)parameters auth:(NSString *)auth completeBlock:(EXUCompleteBlock)complete{
    [self requestServer:path withParameters:parameters auth:auth method:@"POST" completeBlock:complete];
}
+(void)requestServer:(NSString *)path withParameters:(NSDictionary *)parameters auth:(NSString *)auth method:(NSString *)method completeBlock:(EXUCompleteBlock)complete{
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@",apiUrl,path]]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if (auth) {
        [request setValue:auth forHTTPHeaderField:@"Authorization"];
    }
    request.HTTPMethod = method;
    if (parameters) {
        parameters = [parameters copy];
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&error];
        if (jsonData) {
            [request setHTTPBody:jsonData];
        }
    }
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self handleResponse:error complete:complete];
        }else{
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if(httpResponse && [httpResponse statusCode] == 200){
                NSDictionary * dic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
                [self handleResponse:dic complete:complete];
            }else{
                NSError *error = nil;
                if(httpResponse){
                    error = [[NSError alloc] initWithDomain:@"" code:[httpResponse statusCode] userInfo:nil];
                }else{
                    error = [[NSError alloc] initWithDomain:@"" code:-1 userInfo:nil];
                }
              [self handleResponse:error complete:complete];
            }
            
        }
    }];
    [task resume];
}

+ (void)handleResponse:(id)response complete:(EXUCompleteBlock)complete{
    if ([response isKindOfClass:[NSError class]]) {
        if (complete) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = (NSError *)response;
                if(error.code == 404 || error.code == 410){
                    [[NSUserDefaults standardUserDefaults] setValue:@"1" forKey:[NSString stringWithFormat:@"%@%@",StopUsingDataWarehouse,[[NSBundle mainBundle].infoDictionary objectForKey:@"CFBundleShortVersionString"]]];
                }
                complete(FALSE,@(error.code));
            });
        }
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (complete) {
                complete(true,response);
            }
        });
    }
}
@end
