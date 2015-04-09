//
//  NSObject+TCMapping.h
//  TCKit
//
//  Created by ChenQi on 13-12-29.
//  Copyright (c) 2013年 Dake. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NSManagedObjectContext;
@interface NSObject (TCMapping)

/**
 *	propertyNameMapping:
 *  format: @{@"propertyName":@"json'propertyName"}
 
 *	@return	the mapping dictionary
 */
- (NSDictionary *)propertyNameMapping;

/**
 *	propertyTypeFormat
 *  format: @{@"propertyName":@"dataType or object'class name"}
 
 if createDate is a NSDate type ,you can code @"createDate":@"yyyy-MM-dd HH:mm"
 if studentMembers is a NSArray type, you can code the NSArray'member type here , such as  @"studentMembers":@"StudentCD"
 if teacher is a TeacherCD object value , you can code  @"teacher":@"TeacherCD"
 *	@return	the mapping dictionary
 */
- (NSDictionary *)propertyTypeFormat;

+ (NSMutableArray *)mappingWithArray:(NSArray *)arry;
+ (NSMutableArray *)mappingWithArray:(NSArray *)arry managerObjectContext:(NSManagedObjectContext *)context;

- (BOOL)mappingWithDictionary:(NSDictionary *)dic;
- (BOOL)mappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context;


@end
