//
//  TCHTTPBatchRequest.h
//  TCKit
//
//  Created by cdk on 15/3/26.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import "TCHTTPRequest.h"

@interface TCHTTPBatchRequest : TCHTTPRequest

@property(nonatomic,copy,readwrite) NSArray *requestArray;

+ (instancetype)requestWithRequests:(NSArray *)requests;
- (instancetype)initWithRequests:(NSArray *)requests;

- (BOOL)start:(NSError **)error;


@end
