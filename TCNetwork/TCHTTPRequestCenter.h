//
//  TCHTTPRequestCenter.h
//  TCKit
//
//  Created by dake on 15/3/16.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCHTTPRequestCenterProtocol.h"
#import "TCHTTPRequestUrlFilter.h"
#import "TCHTTPRequest.h"

@interface TCHTTPRequestCenter : NSObject <TCHTTPRequestCenterProtocol>

@property(nonatomic,strong) NSURL *baseURL;
@property(nonatomic,strong) NSURL *cdnURL;

@property(nonatomic,assign,readonly) BOOL networkReachable;
// default: 0, use Max(-[TCHTTPRequestCenter timeoutInterval], -[TCHTTPRequest timeoutInterval])
@property(nonatomic,assign) NSTimeInterval timeoutInterval;
@property(nonatomic,assign) NSInteger maxConcurrentOperationCount;
@property(nonatomic,weak) id<TCHTTPRequestUrlFilter> urlFilter;

+ (instancetype)defaultCenter;
- (instancetype)initWithBaseURL:(NSURL *)url;

- (BOOL)addRequest:(TCHTTPRequest *)request error:(NSError **)error;

- (void)addObserver:(__unsafe_unretained id)observer forRequest:(id<TCHTTPRequestProtocol>)request;
- (void)removeRequestObserver:(__unsafe_unretained id)observer forIdentifier:(id<NSCopying>)identifier;
- (void)removeRequestObserver:(__unsafe_unretained id)observer;

- (NSString *)cachePathForResponse;
- (void)removeAllCachedResponse;


#pragma mark - Making HTTP Requests

//
// request method below, will not auto start
- (TCHTTPRequest *)requestWithMethod:(TCHTTPRequestMethod)method apiUrl:(NSString *)apiUrl host:(NSString *)host;
- (TCHTTPRequest *)cacheRequestWithMethod:(TCHTTPRequestMethod)method apiUrl:(NSString *)apiUrl host:(NSString *)host;
- (TCHTTPRequest *)requestForDownload:(NSString *)url to:(NSString *)dstPath;
- (TCHTTPRequest *)batchRequestWithRequests:(NSArray *)requests;

@end
