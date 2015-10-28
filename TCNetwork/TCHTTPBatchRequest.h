//
//  TCHTTPBatchRequest.h
//  TCKit
//
//  Created by cdk on 15/3/26.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import "TCHTTPRequest.h"

@interface TCHTTPBatchRequest : TCHTTPRequest

@property (nonatomic, copy, readwrite) NSArray<__kindof TCHTTPRequest *> *requestArray;

+ (instancetype)requestWithRequests:(NSArray<__kindof TCHTTPRequest *> *)requests;
- (instancetype)initWithRequests:(NSArray<__kindof TCHTTPRequest *> *)requests;

- (BOOL)start:(NSError **)error;


@end
