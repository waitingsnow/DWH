//
//  NSObject+ORM.m
//  ORM
//
//  Created by PengLinmao on 16/11/22.
//  Copyright © 2016年 PengLinmao. All rights reserved.
//

#import "DWHNSObject+ORM.h"
#import "DWHORM.h"
#import "DWHORMDB.h"
@implementation NSObject(Extensions)
static dispatch_queue_t    _queue;
static dispatch_once_t onceToken;
+ (void)dWHCreateTable{
	[DWHORM createTableFromClass:[self class]];
	dispatch_once(&onceToken, ^{
		_queue = dispatch_queue_create([[NSString stringWithFormat:@"DWHORMDB.%@", self] UTF8String], NULL);
	});
}
- (void)dWHSave:(NSArray *)keyes{
	if (!_queue) {
		NSLog(@"ERROR table not created :%@ queue not found",self);
		return;
	}
	dispatch_sync(_queue, ^() {
		[DWHORMDB beginTransaction];
		[DWHORM saveEntity:self with:keyes];
		[DWHORMDB commitTransaction];
	});
}
+(void)dWHSaveListData:(NSArray *)keys andBlock:(void (^) (NSMutableArray *datas))block{
	if (!_queue) {
		NSLog(@"ERROR table not created :%@ queue not found",self);
		return;
	}
	dispatch_sync(_queue, ^() {
		[DWHORMDB beginTransaction];
		NSMutableArray *arr=[[NSMutableArray alloc] init];
		block(arr);
		for (id obj in arr) {
			[DWHORM saveEntity:obj with:keys];
		}
		[DWHORMDB commitTransaction];
	});
}

+ (id)dWHGetObject:(NSArray *)keys withValue:(NSArray *)values{
	__block id obj;
	if (!_queue) {
		NSLog(@"ERROR table not created :%@ queue not found",self);
		return nil;
	}
	dispatch_sync(_queue, ^() {
		obj = [DWHORM get:[self class] withKeys:keys andValues:values];
	});
	return  obj;
}

+ (id)dWHList:(NSArray *)keys withValue:(NSArray *)values{
	__block NSMutableArray *array ;
	if (!_queue) {
		NSLog(@"ERROR table not created :%@ queue not found",self);
		return nil;
	}
	dispatch_sync(_queue, ^() {
		array =  [DWHORM list:[self class] withKeys:keys andValues:values];
	});
	return array;
}

+ (void)dWHClearTable{
	if (!_queue) {
		NSLog(@"ERROR table not created :%@ queue not found",self);
		return;
	}
	dispatch_sync(_queue, ^() {
		[DWHORM deleteObject:[self class] withKeys:nil andValues:nil];
	});
}

+ (void)dWHClearTable:(NSArray *)keys withValue:(NSArray *)value{
	if (!_queue) {
		NSLog(@"ERROR table not created :%@ queue not found",self);
		return;
	}
	dispatch_sync(_queue, ^() {
		[DWHORM deleteObject:[self class] withKeys:keys andValues:value];
	});
}

+ (void)dWHExecSql:(void (^)(DWHSqlOperationQueueObject *db))block{
	if (!_queue) {
		NSLog(@"ERROR table not created :%@ queue not found",self);
		return;
	}
	dispatch_sync(_queue, ^() {
		[DWHORMDB beginTransaction];
		DWHSqlOperationQueueObject *sqlObj=[[DWHSqlOperationQueueObject alloc] init];
		block(sqlObj);
		[DWHORMDB commitTransaction];
	});
	
}

+ (NSMutableArray *)dWHQueryForObjectArray:(NSString *)sql{
	__block NSMutableArray *array ;
	if (!_queue) {
		NSLog(@"ERROR table not created :%@ queue not found",self);
		return nil;
	}
	dispatch_sync(_queue, ^() {
		array = [DWHORMDB queryDB:[self class] andSql:sql];
	});
	return  array;
}

+ (NSMutableDictionary *)dWHQueryForDictionary:(NSString *)sql{
	__block NSMutableDictionary *dic;
	if (!_queue) {
		NSLog(@"ERROR table not created :%@ queue not found",self);
		return nil;
	}
	dispatch_sync(_queue, ^() {
		dic = [DWHORMDB queryWithSql:sql];
	});
	return  dic;
}
@end

@implementation NSArray(ORM)

-(void)dWHSaveListDataWithKeys:(NSArray *)keys{
	if (!_queue) {
		NSLog(@"ERROR table not created :%@ queue not found",self);
		return;
	}
	dispatch_sync(_queue, ^() {
		[DWHORMDB beginTransaction];
		for (id obj in self) {
			[DWHORM saveEntity:obj with:keys];
		}
		[DWHORMDB commitTransaction];
	});
}

@end

@implementation DWHSqlOperationQueueObject

/**
 执行update sql
 **/
- (void)dWHExecUpdate:(NSString *)sql{
	[DWHORMDB execsql:sql];
}

/**
 执行select sql
 **/
- (void)dWHExecDelete:(NSString *)sql{
	[DWHORMDB execsql:sql];
}

/**
 根据 select sql 返回是否 存在结果集
 
 select * from XXX where uid=1 ;
 return false 标识 不存在uid=1的数据
 **/
- (BOOL)dWHRowExist:(NSString *)sql{
	return	[DWHORMDB rowExist:sql];
}

@end
