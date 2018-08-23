//
//  ViewController.m
//  DWHSDK
//
//  Created by mao PengLin on 2018/6/27.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import "ViewController.h"
#import "DWHSDK.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton *test = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    test.backgroundColor = [UIColor redColor];
    [self.view addSubview:test];
    [test setTitle:@"event" forState:UIControlStateNormal];
    [test addTarget:self action:@selector(testClick) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *test2 = [[UIButton alloc] initWithFrame:CGRectMake(100, 300, 100, 100)];
    test2.backgroundColor = [UIColor blueColor];
    [self.view addSubview:test2];
    [test2 addTarget:self action:@selector(testClick2) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *test22 = [[UIButton alloc] initWithFrame:CGRectMake(100, 370, 100, 100)];
    test22.backgroundColor = [UIColor blueColor];
    [test22 setTitle:@"E 2" forState:UIControlStateNormal];
    [self.view addSubview:test22];
    [test22 addTarget:self action:@selector(testClick3) forControlEvents:UIControlEventTouchUpInside];
}
- (void)testClick3{
    [[DWHSDK dwhSDK] logEvent:@"testEvent" withEventProperties:@{}];
//    [[DWHSDK dwhSDK] setUserId:@"5702364" withProperties:@{@"gender":@"M",@"nation":@"Germany",@"timezone":@2}];
}
- (void)testClick2{
    for (int i=100; i<1; i++) {
        [[DWHSDK dwhSDK] updateUserProperties:@{@"f":@1,@"s":@(1),@"i":@(i)}];
    }
}

- (void)testClick{
    dispatch_queue_t t =  dispatch_queue_create("hw_queue_event_handle", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(t, ^{
        for (int i=0; i<100; i++) {
            [[DWHSDK dwhSDK] logEvent:[NSString stringWithFormat:@"testEvent%i",i] withEventProperties:@{@"eeeeee":@"bbb",@"number":@(i)}];
        }
    });
    for (int i=100; i<200; i++) {
        [[DWHSDK dwhSDK] logEvent:[NSString stringWithFormat:@"testEvent%i",i] withEventProperties:@{@"eeeeee":@"bbb",@"number":@(i)}];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
