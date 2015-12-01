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


@class AFSecurityPolicy;
NS_CLASS_AVAILABLE_IOS(7_0) @interface TCHTTPRequestCenter : NSObject <TCHTTPRequestCenterProtocol>

@property (nonatomic, strong) NSURL *baseURL;

@property (nonatomic, assign, readonly) BOOL networkReachable;
// default: 0, use Max(-[TCHTTPRequestCenter timeoutInterval], -[TCHTTPRequest timeoutInterval])
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, assign) NSInteger maxConcurrentCount;
@property (nonatomic, strong) NSSet *acceptableContentTypes;
@property (nonatomic, weak) id<TCHTTPRequestUrlFilter> urlFilter;

+ (instancetype)defaultCenter;
- (instancetype)initWithBaseURL:(NSURL *)url;
- (instancetype)initWithBaseURL:(NSURL *)url sessionConfiguration:(NSURLSessionConfiguration *)configuration;
- (AFSecurityPolicy *)securityPolicy;

- (BOOL)addRequest:(TCHTTPRequest *)request error:(NSError **)error;

- (void)addObserver:(__unsafe_unretained id)observer forRequest:(id<TCHTTPRequestProtocol>)request;
- (void)removeRequestObserver:(__unsafe_unretained id)observer forIdentifier:(id<NSCopying>)identifier;
- (void)removeRequestObserver:(__unsafe_unretained id)observer;

- (NSString *)cachePathForResponse;
- (void)removeAllCachedResponse;

- (void)registerResponseValidatorClass:(Class)validatorClass;


#pragma mark - Custom value in HTTP Head

@property (nonatomic, strong) NSDictionary<__kindof NSString *, __kindof NSString *> *customHeaderValue;

/**
 Sets the "Authorization" HTTP header set in request objects made by the HTTP client to a basic authentication value with Base64-encoded username and password. This overwrites any existing value for this header.
 */
@property (nonatomic, copy) NSString *authorizationUsername;
@property (nonatomic, copy) NSString *authorizationPassword;


#pragma mark - Making HTTP Requests

//
// request method below, will not auto start
- (TCHTTPRequest *)requestWithMethod:(TCHTTPRequestMethod)method apiUrl:(NSString *)apiUrl host:(NSString *)host cache:(BOOL)cache;
- (TCHTTPRequest *)requestWithMethod:(TCHTTPRequestMethod)method apiUrl:(NSString *)apiUrl host:(NSString *)host;
- (TCHTTPRequest *)cacheRequestWithMethod:(TCHTTPRequestMethod)method apiUrl:(NSString *)apiUrl host:(NSString *)host;
- (TCHTTPRequest *)requestForDownload:(NSString *)url to:(NSString *)dstPath cache:(BOOL)cache;
- (TCHTTPRequest *)batchRequestWithRequests:(NSArray *)requests;

@end
