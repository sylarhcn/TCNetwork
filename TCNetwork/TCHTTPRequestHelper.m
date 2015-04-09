//
//  TCHTTPRequestHelper.m
//  TCKit
//
//  Created by dake on 15/3/15.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import "TCHTTPRequestHelper.h"
#import <CommonCrypto/CommonDigest.h>


@implementation TCHTTPRequestHelper

//+ (BOOL)isValue:(id)json confirmType:(id)validatorJson
//{
//    if ([json isKindOfClass:[NSDictionary class]] && [validatorJson isKindOfClass:[NSDictionary class]]) {
//        BOOL result = YES;
//        NSDictionary *dict = json;
//        NSDictionary *validator = validatorJson;
//        
//        for (NSString *key in validator) {
//            id value = dict[key];
//            id type = validator[key];
//            
//            if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]]) {
//                result = [self isValue:value confirmType:type];
//                break;
//            }
//            else if (nil != value && ![value isKindOfClass:type] && ![value isKindOfClass:[NSNull class]]) {
//                result = NO;
//                break;
//            }
//        }
//        
//        return result;
//    }
//    else if ([json isKindOfClass:[NSArray class]] && [validatorJson isKindOfClass:[NSArray class]]) {
//        BOOL result = YES;
//        NSArray *validatorArray = (NSArray *)validatorJson;
//        if (validatorArray.count > 0) {
//            NSDictionary *type = validatorArray.firstObject;
//            for (id value in (NSArray *)json) {
//                result = [self isValue:value confirmType:type];
//                if (!result) {
//                    break;
//                }
//            }
//        }
//        return result;
//    }
//    else if ([json isKindOfClass:validatorJson]) {
//        return YES;
//    }
//    else {
//        return NO;
//    }
//}

+ (NSString *)urlString:(NSString *)originUrlString appendParameters:(NSDictionary *)parameters
{
    NSString *url = originUrlString;
    NSString *paraUrlString = [parameters convertToHttpQuery];
    
    if (nil != paraUrlString && paraUrlString.length > 0) {
        if ([originUrlString rangeOfString:@"?"].location != NSNotFound) {
            url = [originUrlString stringByAppendingString:paraUrlString];
        }
        else {
            url = [originUrlString stringByAppendingFormat:@"?%@", [paraUrlString substringFromIndex:1]];
        }
    }
    
    return url;
}


@end


@implementation NSDictionary (TCHelper)

- (NSString *)convertToHttpQuery
{
    NSMutableString *queryString = nil;
    if (self.count > 0) {
        queryString = [[NSMutableString alloc] init];
        for (NSString *key in self.allKeys) {
            NSString *value = self[key];
            value = [NSString stringWithFormat:@"%@",value];
            value = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)value, CFSTR("."), CFSTR(":/?#[]@!$&'()*+,;="), kCFStringEncodingUTF8);
            [queryString appendFormat:@"&%@=%@", key, value];
        }
    }
    return queryString;
}

- (id)valueForKeyExceptNull:(NSString *)key
{
    id obj = [self valueForKey:key];
    
    return [NSNull null] == obj ? nil : obj;
}


@end


#pragma mark - MD5

@implementation NSString (MD5)

- (NSString *)MD5_32
{
    if (self.length < 1) {
        return nil;
    }
    
    const char *value = [self UTF8String];
    
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);
    
    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++) {
        [outputString appendFormat:@"%02x",outputBuffer[count]];
    }
    
    return outputString;
}

- (NSString *)MD5_16
{
    NSString *str = [self MD5_32];
    return nil != str ? [str substringWithRange:NSMakeRange(8, 16)] : str;
}

@end
