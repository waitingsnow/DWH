//
//  TestLab.m
//  DWHSDK
//
//  Created by mao PengLin on 2018/11/20.
//  Copyright © 2018年 mao PengLin. All rights reserved.
//

#import "TestLab.h"

@implementation TestLab

- (instancetype)initWithFrame:(CGRect)frame{
	self = [super initWithFrame:frame];
	if (self) {
		CATiledLayer *tiledLayer = (CATiledLayer *)self.layer;
		tiledLayer.levelsOfDetailBias = 24;
		tiledLayer.levelsOfDetail = 24;
		self.opaque = YES;
	}
	return self;
}

+ (Class)layerClass {
    return [CATiledLayer class];
}

@end
