//
//  ViewController.m
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/27.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import "ViewController.h"
#import <DWH/DWH.h>
#import "TestLab.h"

@interface ViewController ()

@property (nonatomic, assign) long long startTime;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *test = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    test.backgroundColor = [UIColor redColor];
    [self.view addSubview:test];
    [test setTitle:@"event" forState:UIControlStateNormal];
    [test addTarget:self action:@selector(testClick) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *test2 = [[UIButton alloc] initWithFrame:CGRectMake(220, 200, 80, 100)];
    test2.backgroundColor = [UIColor blueColor];
    [self.view addSubview:test2];
    [test2 setTitle:@"date" forState:UIControlStateNormal];
    [test2 addTarget:self action:@selector(testClick2) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *test22 = [[UIButton alloc] initWithFrame:CGRectMake(100, 370, 100, 100)];
    test22.backgroundColor = [UIColor blueColor];
    [test22 setTitle:@"E 2" forState:UIControlStateNormal];
    [self.view addSubview:test22];
    [test22 addTarget:self action:@selector(testClick3) forControlEvents:UIControlEventTouchUpInside];
    self.startTime = [[NSProcessInfo processInfo] systemUptime];
    NSLog(@"strtTime:%lld",self.startTime);
    
//    TestLab *t = [[TestLab alloc] initWithFrame:CGRectMake(300, 200, 80, 25)];
//    t.text = @"测试文字";
//    t.textColor = [UIColor blackColor];
//    [self.view addSubview:t];
//
//    t.transform = CGAffineTransformMakeScale(15, 15);
}

- (void)testClick3{
    NSLog(@"t2:%f",[[NSProcessInfo processInfo] systemUptime]-self.startTime);
    if ( [[NSDate date] timeIntervalSince1970]>100000000000) {
        NSLog(@"毫秒");
    }else{
        NSLog(@"秒");
    }
    NSLog(@"t3:%lld",(long long)(([[NSProcessInfo processInfo] systemUptime]-self.startTime)*1000));
    [[DWHSDK dwhSDK] logEvent:@"testEvent" withEventProperties:@{@"ccc":@"dd"}];
//    [[DWHSDK dwhSDK] setUserId:@"5702364" withProperties:@{@"gender":@"M",@"nation":@"Germany",@"timezone":@2}];
}

- (void)testClick2{
//    [[DWHSDK dwhSDK] setServerTime:[[NSDate date] timeIntervalSince1970]*1000];
}

- (void)testClick{
//    return;
//    dispatch_queue_t t =  dispatch_queue_create("hw_queue_event_handle", DISPATCH_QUEUE_CONCURRENT);
//    dispatch_async(t, ^{
        for (int i=0; i<1; i++) {
            [[DWHSDK dwhSDK] logEvent:[NSString stringWithFormat:@"testEvent%i",i] withEventProperties:@{@"eeeeee":@"bbb",@"number":@(i)}];
        }
//    });
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
