//
//  ORMDB.h
//  ORM
//
//  Created by PengLinmao on 16/11/22.
//  Copyright © 2016年 PengLinmao. All rights reserved.
//

#import <Foundation/Foundation.h>


static BOOL showsql =  true;
@interface DWHORMDB : NSObject

/**
 设置数据库路径
 **/
+(void)configDBPath:(NSString *)path showLog:(BOOL)showLog;
/**
 开启事物
 **/
+(void)beginTransaction;
/**
 关闭事物
 **/
+(void)commitTransaction;

/**
 自定义查询
 **/
+ (NSMutableDictionary *)queryWithSql:(NSString *)sql;
/**
 自定义查询
 **/
+ (NSMutableArray *)queryDB:(Class)cls andSql:(NSString *)sql;
+(void)execsql:(NSString *)sql;
+(void)saveObject:(id)object withSql:(NSString *)sql;
+(BOOL)rowExist:(NSString *)sql;
+ (BOOL)columnExists:(NSString *)tableName andColumnName:(NSString *)column;
@end
