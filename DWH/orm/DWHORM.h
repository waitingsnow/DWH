//
//  ORM.h
//  ORM
//
//  Created by PengLinmao on 16/11/22.
//  Copyright © 2016年 PengLinmao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

NS_ASSUME_NONNULL_BEGIN

#define force_inline __inline__ __attribute__((always_inline))

static force_inline NSNumber * __nullable ORMDBNumberCreateFromID(__unsafe_unretained id __nullable value) {
	static NSCharacterSet *dot;
	static NSDictionary *dic;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		dot = [NSCharacterSet characterSetWithRange:NSMakeRange('.', 1)];
		dic = @{@"TRUE" :   @(YES),
				@"True" :   @(YES),
				@"true" :   @(YES),
				@"FALSE" :  @(NO),
				@"False" :  @(NO),
				@"false" :  @(NO),
				@"YES" :    @(YES),
				@"Yes" :    @(YES),
				@"yes" :    @(YES),
				@"NO" :     @(NO),
				@"No" :     @(NO),
				@"no" :     @(NO),
				@"NIL" :    (id)kCFNull,
				@"Nil" :    (id)kCFNull,
				@"nil" :    (id)kCFNull,
				@"NULL" :   (id)kCFNull,
				@"Null" :   (id)kCFNull,
				@"null" :   (id)kCFNull,
				@"(NULL)" : (id)kCFNull,
				@"(Null)" : (id)kCFNull,
				@"(null)" : (id)kCFNull,
				@"<NULL>" : (id)kCFNull,
				@"<Null>" : (id)kCFNull,
				@"<null>" : (id)kCFNull};
	});
	
	if (!value || value == (id)kCFNull) return nil;
	if ([value isKindOfClass:[NSNumber class]]) return value;
	if ([value isKindOfClass:[NSString class]]) {
		NSNumber *num = dic[value];
		if (num) {
			if (num == (id)kCFNull) return nil;
			return num;
		}
		if ([(NSString *)value rangeOfCharacterFromSet:dot].location != NSNotFound) {
			const char *cstring = ((NSString *)value).UTF8String;
			if (!cstring) return nil;
			double num = atof(cstring);
			if (isnan(num) || isinf(num)) return nil;
			return @(num);
		} else {
			const char *cstring = ((NSString *)value).UTF8String;
			if (!cstring) return nil;
			return @(atoll(cstring));
		}
	}
	return nil;
}

static force_inline NSString * __nullable createWhereStatement(NSArray * __nullable key, NSArray * __nullable value) {
	NSString *whereSql=@"";
	for (int i=0; i<key.count; i++) {
		NSString *type=[NSString stringWithFormat:@"%@",[value[i] class]];
		
		if (i==0) {
			if ([type hasSuffix:@"NSCFNumber"]||[type hasSuffix:@"NSCFBoolean"]) {
				if ([type hasSuffix:@"NSCFNumber"]) {
					NSNumber *number=value[i];
					if(CFNumberIsFloatType((CFNumberRef)number))
					{
						whereSql=[NSString stringWithFormat:@"WHERE %@ = %@ ",key[i],value[i]];
					}else{
						whereSql=[NSString stringWithFormat:@"WHERE %@ = %i ",key[i],[value[i] intValue]];
					}
				}else{
					whereSql=[NSString stringWithFormat:@"WHERE %@ = %i ",key[i],[value[i] intValue]];
				}
			}
			else{
				whereSql=[NSString stringWithFormat:@"WHERE %@ = '%@' ",key[i],value[i]];
			}
		}else{
			if ([type hasSuffix:@"NSCFNumber"]||[type hasSuffix:@"NSCFBoolean"]) {
				if ([type hasSuffix:@"NSCFNumber"]) {
					NSNumber *number=value[i];
					if(CFNumberIsFloatType((CFNumberRef)number)){
						whereSql=[NSString stringWithFormat:@"%@ AND  %@ = %@  ",whereSql,key[i],value[i]];
					}else{
						whereSql=[NSString stringWithFormat:@"%@ AND  %@ = %i  ",whereSql,key[i],[value[i] intValue]];
					}
					
				}else{
					whereSql=[NSString stringWithFormat:@"%@ AND  %@ = %i  ",whereSql,key[i],[value[i] intValue]];
				}
			}else{
				whereSql=[NSString stringWithFormat:@"%@ AND  %@ = '%@'  ",whereSql,key[i],value[i]];
			}
		}
	}
	return whereSql;
}

typedef NS_OPTIONS (NSUInteger ,ORMDBDataType){
	ORMDBDataTypeUnknown,
	ORMDBDataTypeBool,
	ORMDBDataTypeInt,
	ORMDBDataTypeFloat,
	ORMDBDataTypeDouble,
	ORMDBDataTypeClass,
	ORMDBDataTypeString,
	ORMDBDataTypeNumber,
	ORMDBDataTypeArray,
	ORMDBDataTypeMutableArray,
	ORMDBDataTypeDictionary,
	ORMDBDataTypeMutableDictionary,
	ORMDBDataTypeNSDate
};

@protocol DWHORM <NSObject>

@optional
/**
 创建表时忽略字段
 **/
+(NSArray<NSString *> *)sqlIgnoreColumn;
/**
 主键
 **/
+(NSString *)primarilyKey;

/**
 外键
 **/
+(NSString *)foreignKey;

/**
 外键映射表操作类型
 实现此方法 标识 关联字段不创建表，而是自动插入 或者 更新 到指定的表
 key=>column
 value=>tableName
 
 +(NSDictionary<NSString *, NSString *> *_Nonnull)foreignKeyNotCreateTable{
	return @{@"conversation_user":@"EXUPersonInfo"};
 }
 **/
+(NSDictionary<NSString *, NSString *> *)foreignKeyNotCreateTable;

@end

@interface DWHORM : NSObject

+ (void)createTableFromClass:(Class __nullable) cls;
+ (void)saveEntity:(id __nullable)entity with:(NSArray * __nullable)keys;
+ (id __nullable)get:(Class __nullable)cls withKeys:(NSArray * __nullable)keys andValues:(NSArray * __nullable)values;
+ (NSMutableArray *__nullable)list:(Class __nullable)cls withKeys:(NSArray * __nullable)keys andValues:(NSArray * __nullable)values;
+ (void)deleteObject:(Class __nullable)cls withKeys:(NSArray * __nullable)keys andValues:(NSArray * __nullable)values;

@end


@interface DWHORMDBClassPropertyInfo : NSObject

@property (nonatomic, assign, readonly, nullable) objc_property_t property;
@property (nonatomic, strong, readonly, nullable) NSString *name;
@property (nonatomic, strong, readonly, nullable) NSString *typeEncoding;
@property (nonatomic, assign, readonly) ORMDBDataType type;
@property (nonatomic, assign, readonly, nullable) Class cls;
@property (nonatomic, strong, readonly, nullable) NSString *protocol;
@property (nonatomic, strong, nullable) NSString  *foreignTableName;

@end


@interface DWHORMDBClassInfo : NSObject

+ (instancetype __nullable)metaWithClass:(Class __nullable)cls;

@property (nonatomic, assign, readonly, nullable) Class cls;
@property (nonatomic, strong, readonly, nullable) NSString *name;
@property (nonatomic, strong, readonly, nullable) NSMutableArray *propertyInfos;

@end

static force_inline NSString * __nullable SelectColumn(Class __nullable cls) {
	DWHORMDBClassInfo *obj=[DWHORMDBClassInfo metaWithClass:cls];
	NSMutableString *column=[[NSMutableString alloc] init];
	for (DWHORMDBClassPropertyInfo *info in obj.propertyInfos) {
		if (info.type!=ORMDBDataTypeClass&&
			info.type!=ORMDBDataTypeArray&&
			info.type!=ORMDBDataTypeMutableArray&&
			info.type!=ORMDBDataTypeUnknown){
			[column appendFormat:@"%@,",info.name];
		}
	}
	if (column.length-1>0) {
		[column deleteCharactersInRange:NSMakeRange([column length]-1, 1)];
	}
	return column;
}

NS_ASSUME_NONNULL_END
