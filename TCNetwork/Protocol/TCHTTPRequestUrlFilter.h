//
//  TCHTTPRequestUrlFilter.h
//  TCKit
//
//  Created by dake on 15/3/19.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TCHTTPRequestUrlFilter <NSObject>

@optional
- (NSString *)filteredUrlForUrl:(NSString *)url;
- (NSDictionary *)filteredParamForParam:(NSDictionary *)param;

@end
