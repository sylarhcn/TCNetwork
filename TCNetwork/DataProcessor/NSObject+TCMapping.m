//
//  NSObject+TCMapping.m
//  TCKit
//
//  Created by ChenQi on 13-12-29.
//  Copyright (c) 2013年 Dake. All rights reserved.
//

#import "NSObject+TCMapping.h"
#import <objc/runtime.h>

#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0)
@import CoreData;
#else
#import <CoreData/CoreData.h>
#endif


#if ! __has_feature(objc_arc)
#error this file is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif


static const char *property_getTypeName(objc_property_t property)
{
	const char *attributes = property_getAttributes(property);
	char buffer[1 + strlen(attributes)];
	strcpy(buffer, attributes);
	char *state = buffer, *attribute;
	while ((attribute = strsep(&state, ",")) != NULL) {
		if (attribute[0] == 'T') {
			size_t len = strlen(attribute);
			attribute[len - 1] = '\0';
			return (const char *)[[NSData dataWithBytes:(attribute + 3) length:len - 2] bytes];
		}
	}
	return "@";
}



static NSMutableDictionary *s_propertyClassByClassAndPropertyName;
@implementation NSObject (TCMapping)

- (NSDictionary *)propertyNameMapping
{
    return nil;
}

- (NSDictionary *)propertyTypeFormat
{
    return nil;
}


+ (NSMutableArray *)mappingWithArray:(NSArray *)arry
{
    return [self mappingWithArray:arry managerObjectContext:nil];
}

+ (NSMutableArray *)mappingWithArray:(NSArray *)arry managerObjectContext:(NSManagedObjectContext *)context
{
    if (nil == arry || ![arry isKindOfClass:[NSArray class]] || arry.count < 1) {
        return nil;
    }
    
    NSMutableArray *outArry = [NSMutableArray array];
    for (NSDictionary *dic in arry) {
        id obj = [[self alloc] init];
        if ([obj mappingWithDictionary:dic managerObjectContext:context]) {
            [outArry addObject:obj];
        }
    }
    
    return outArry;
}

- (BOOL)mappingWithDictionary:(NSDictionary *)dic
{
    return [self mappingWithDictionary:dic managerObjectContext:nil];
}

- (BOOL)mappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context
{
    if (nil == dic || ![dic isKindOfClass:[NSDictionary class]] || dic.count < 1) {
        return NO;
    }
    
    NSDictionary *nameMappingDic = [self propertyNameMapping];
    NSDictionary *typeMappingDic = [self propertyTypeFormat];
    
    for (NSString *nameKey in [nameMappingDic allKeys]) {
        if (nil == nameKey || [NSNull null] == (NSNull *)nameKey) {
            continue;
        }
        id key = nameMappingDic[nameKey];
        id value = [dic objectForKey:key];
        if (nil == value
            || [NSNull null] == value
            || (context != nil && [[self class] isPropertyReadOnly:[self class] propertyName:nameKey])) {
            continue;
        }
        
        if ([value isKindOfClass:[NSDictionary class]]) {
            if ([(NSDictionary *)value count] > 0) {
                Class klass = NSClassFromString(typeMappingDic[nameKey]);
                value = [self mappingDictionary:value toClass:klass withContext:context];
            }
            else {
                value = nil;
            }
        }
        else if ([value isKindOfClass:[NSArray class]]) {
            if ([(NSArray *)value count] > 0) {
                Class arrayItemType = NSClassFromString(typeMappingDic[nameKey]);
                value = [self mappingArray:value toClass:arrayItemType withContext:context];
            }
            else {
                value = nil;
            }
        }
        else {
            value = [self mappingObjectWithKey:nameKey value:value typeMappingDic:typeMappingDic];
            if (nil == value) {
                NSAssert(false, @"value not correspond to property type.");
                return NO;
            }
        }
        
        
        if (nil != value) {
            [self setValue:value forKey:nameKey];
        }
    }
    
    return YES;
}

- (id)mappingDictionary:(NSDictionary *)value toClass:(Class)klass withContext:(NSManagedObjectContext *)context
{
    NSDictionary *tempDic = value;
    
    if (nil != context) {
        tempDic = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(klass) inManagedObjectContext:context];
        [tempDic mappingWithDictionary:value managerObjectContext:context];
    }
    else {
        tempDic = [[klass alloc] init];
        [tempDic mappingWithDictionary:value managerObjectContext:nil];
    }

    return tempDic;
}

- (NSArray *)mappingArray:(NSArray *)value toClass:(Class)arrayItemType withContext:(NSManagedObjectContext *)context
{
    NSMutableArray *childObjects = [NSMutableArray arrayWithCapacity:value.count];
    
    for (id child in value) {
        if ([[child class] isSubclassOfClass:[NSDictionary class]]) {
            NSObject *childDTO;
            if (nil != context) {
                childDTO = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(arrayItemType) inManagedObjectContext: context];
                [childDTO mappingWithDictionary:child managerObjectContext:context];
            }
            else {
                childDTO = [[arrayItemType alloc] init];
                [childDTO mappingWithDictionary:child managerObjectContext:nil];
            }
            
            [childObjects addObject:childDTO];
        }
        else {
            [childObjects addObject:child];
        }
    }
    
    return childObjects;
}

- (id)mappingObjectWithKey:(id)key value:(id)value typeMappingDic:(NSDictionary *)typeMappingDic
{
    Class propertyClass = [[self class] propertyClassForPropertyName:key ofClass:[self class]];
    
    id retunValue = nil;
    if (propertyClass == [NSDate class]) {
        if ([value isKindOfClass:[NSString class]]) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:typeMappingDic[key]];
            retunValue = [formatter dateFromString:value];
        }
    }
    else if ([value isKindOfClass:propertyClass]) {
        retunValue = value;
    }
    
    return retunValue;
}


#pragma mark - MappingRuntimeHelper

/**
 *	Judge  if the property is readOnly
 *
 *	@param	klass	the property'owner class
 *	@param	propertyName
 *
 *	@return	<#return value description#>
 */
+ (BOOL)isPropertyReadOnly:(Class)klass propertyName:(NSString *)propertyName
{
    const char *type = property_getAttributes(class_getProperty(klass, [propertyName UTF8String]));
    NSString *typeString = [NSString stringWithUTF8String:type];
    NSArray *attributes = [typeString componentsSeparatedByString:@","];
    NSString *typeAttribute = [attributes firstObject];
    
    return [typeAttribute rangeOfString:@"R"].length > 0;
}

/**
 *	return property'class by the property'name
 *
 *	@param	propertyName	<#propertyName description#>
 *	@param	klass	<#klass description#>
 *
 *	@return	property'class by the property'name
 */
+ (Class)propertyClassForPropertyName:(NSString *)propertyName ofClass:(Class)klass
{
	if (nil == s_propertyClassByClassAndPropertyName) {
        s_propertyClassByClassAndPropertyName = [[NSMutableDictionary alloc] init];
    }
	
	NSString *key = [NSString stringWithFormat:@"%@:%@", NSStringFromClass(klass), propertyName];
	NSString *value = [s_propertyClassByClassAndPropertyName objectForKey:key];
	
	if (nil != value) {
		return NSClassFromString(value);
	}
	
	unsigned int propertyCount = 0;
	objc_property_t *properties = class_copyPropertyList(klass, &propertyCount);
	
	const char *cPropertyName = [propertyName UTF8String];
	
	for (unsigned int i = 0; i < propertyCount; ++i) {
		objc_property_t property = properties[i];
		const char *name = property_getName(property);
        
		if (strcmp(cPropertyName, name) == 0) {
			free(properties);
            NSString *className;
            if (property_getTypeName(property) != NULL) {
                className = [NSString stringWithUTF8String:property_getTypeName(property)];
            }
            else {
                className = @"bool";
            }
			[s_propertyClassByClassAndPropertyName setObject:className forKey:key];
            // we found the property - we need to free
			return NSClassFromString(className);
		}
	}
    
    free(properties);
    
	return [self propertyClassForPropertyName:propertyName ofClass:class_getSuperclass(klass)];
}


@end
