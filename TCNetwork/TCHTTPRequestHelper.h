//
//  TCHTTPRequestHelper.h
//  TCKit
//
//  Created by dake on 15/3/15.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TCHTTPRequestHelper : NSObject

//+ (BOOL)isValue:(id)json confirmType:(id)validator;
+ (NSString *)urlString:(NSString *)originUrlString appendParameters:(NSDictionary *)parameters;

@end


@interface NSDictionary (TCHelper)

- (NSString *)convertToHttpQuery;
- (id)valueForKeyExceptNull:(NSString *)key;

@end

@interface NSString (MD5)

// for MD5
- (NSString *)MD5_32;
- (NSString *)MD5_16;

@end