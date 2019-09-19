//
//  NSObject+ORM.h
//  ORM
//
//  Created by PengLinmao on 16/11/22.
//  Copyright © 2016年 PengLinmao. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DWHSqlOperationQueueObject : NSObject
/**
 执行update sql
 **/
- (void)dWHExecUpdate:(NSString *)sql;

/**
 执行select sql
 **/
- (void)dWHExecDelete:(NSString *)sql;

/**
 根据 select sql 返回是否 存在结果集
 
 select * from XXX where uid=1 ;
 
 return false 标识 不存在uid=1的数据
 **/
- (BOOL)dWHRowExist:(NSString *)sql;
@end

@interface NSObject(Extensions)
/**
 创建表
 **/
+ (void)dWHCreateTable;

/**
 保存数据
 @param keyes 数据保存参数条件
 **/
- (void)dWHSave:(NSArray *)keyes;

/**
 查询单个对象
 @param keys 参数条件
 @param values 值
 **/
+ (id)dWHGetObject:(NSArray *)keys withValue:(NSArray *)values;

/**
 查询列表
 **/
+ (id)dWHList:(NSArray *)keys withValue:(NSArray *)values;

/**
 清空表数据
 **/
+ (void)dWHClearTable;

/**
 清空特定条件数据
 **/
+ (void)dWHClearTable:(NSArray *)keys withValue:(NSArray *)value;

/**
 保存列表集合数据
 @param keys 参数条件
 @param block 回调参数
 **/
+ (void)dWHSaveListData:(NSArray *)keys
			   andBlock:(void (^)(NSMutableArray *datas))block;


/**
 自定义sql查询，并返回封装对象的结果 集合
 **/
+ (NSMutableArray *)dWHQueryForObjectArray:(NSString *)sql;

/**
	只返回 一行查询结果，通过字段名字取值
 
	NSMutableDictionary *result= [XXX queryWithSql:@"select * from User"];
 
	result[@"columnName"];
 */
+ (NSMutableDictionary *)dWHQueryForDictionary:(NSString *)sql;

/**
 执行自定义 sql  update/insert
 **/
+ (void)dWHExecSql:(void (^)(DWHSqlOperationQueueObject *db))block;

@end

@interface NSArray(ORM)

/**
 存储匹配的数据
 **/
- (void)dWHSaveListDataWithKeys:(NSArray *)keys;

@end

NS_ASSUME_NONNULL_END
