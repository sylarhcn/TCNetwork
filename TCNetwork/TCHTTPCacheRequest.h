//
//  TCHTTPCacheRequest.h
//  TCKit
//
//  Created by dake on 15/3/16.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import "TCHTTPRequest.h"

@interface TCHTTPCacheRequest : TCHTTPRequest

@property(nonatomic,assign) BOOL shouldIgnoreCache; // default: NO
@property(nonatomic,assign) BOOL shouldCacheResponse; // default: YES
@property(nonatomic,assign) NSTimeInterval cacheTimeoutInterval; // default: 0, expired anytime, < 0: never expired
@property(nonatomic,assign) BOOL isDataFromCache;
// should return expired cache or not
@property(nonatomic,assign) BOOL shouldExpiredCacheValid; // default: NO


/**
 @brief	fire a request regardless of cache available
 if cache is available, callback then fire a request.
 
 @param error [OUT] <#error description#>
 
 @return <#return value description#>
 */
- (BOOL)forceStart:(NSError **)error;
- (id)cacheResponse;

// default: parameters = self.parameters, sensitiveData = nil
- (void)setCachePathFilterWithRequestParameters:(NSDictionary *)parameters
                                  sensitiveData:(id)sensitiveData;

@end
