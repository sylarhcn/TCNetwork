//
//  TCHTTPCacheRequest.m
//  TCKit
//
//  Created by dake on 15/3/16.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import "TCHTTPCacheRequest.h"
#import "TCHTTPRequestHelper.h"


@implementation TCHTTPCacheRequest
{
    @private
    NSDictionary *_parametersForCachePathFilter;
    id _sensitiveDataForCachePathFilter;
    id _cacheResponse;
}

@dynamic isForceStart;

@synthesize isCacheExpired = _isCacheExpired;
@synthesize shouldIgnoreCache = _shouldIgnoreCache;
@synthesize shouldCacheResponse = _shouldCacheResponse;
@synthesize cacheTimeoutInterval = _cacheTimeoutInterval;
@synthesize isDataFromCache = _isDataFromCache;
@synthesize shouldExpiredCacheValid = _shouldExpiredCacheValid;


- (instancetype)init
{
    self = [super init];
    if (self) {
        self.shouldCacheResponse = YES;
    }
    return self;
}

- (id)cacheResponse
{
    if (nil == _cacheResponse) {
        NSString *path = self.cacheFilePath;
        BOOL isDir = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || isDir) {
            return nil;
        }
        
        @try {
            _cacheResponse = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        }
        @catch (NSException *exception) {
            NSLog(@"%@", exception);
        }
        @finally {
            self.isDataFromCache = nil != _cacheResponse;
        }
    }
    return _cacheResponse;
}

- (void)clearCacheResponse
{
    [self requestRespondReset];
    self.isCacheExpired = self.cacheTimeoutInterval == 0;
}

- (id)responseObject
{
    if (nil != _cacheResponse) {
        return _cacheResponse;
    }
    return [super responseObject];
}

- (NSDictionary *)parametersForCachePathFilter
{
    return _parametersForCachePathFilter ?: self.parameters;
}

- (void)setCachePathFilterWithRequestParameters:(NSDictionary *)parameters
                                  sensitiveData:(id)sensitiveData;
{
    _parametersForCachePathFilter = parameters;
    _sensitiveDataForCachePathFilter = sensitiveData;
}


- (void)requestRespondReset
{
    [super requestRespondReset];
    _cacheResponse = nil;
    self.isDataFromCache = NO;
}

- (void)requestRespondSuccess
{
    [super requestRespondSuccess];
    
    [self clearCacheResponse];
    
    if (self.shouldCacheResponse && self.cacheTimeoutInterval != 0) {
        NSString *path = self.cacheFilePath;
        if (nil != path
            && ![NSKeyedArchiver archiveRootObject:self.responseObject toFile:self.cacheFilePath]) {
            NSAssert(false, @"write response failed.");
        }
    }
}

- (void)requestRespondFailed
{
    [super requestRespondFailed];
    [self requestRespondReset];
}

- (BOOL)isCacheAvailable
{
    NSString *path = self.cacheFilePath;
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || isDir) {
        return NO;
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    
    if (nil != attributes && (self.cacheTimeoutInterval < 0 || -attributes.fileModificationDate.timeIntervalSinceNow < self.cacheTimeoutInterval)) {
        return YES;
    }
    else {
        self.isCacheExpired = -attributes.fileModificationDate.timeIntervalSinceNow >= self.cacheTimeoutInterval;
        return NO;
    }
}

- (void)cacheRequestCallback
{
    BOOL isValid = YES;
    if (nil != self.responseValidator && [self.responseValidator respondsToSelector:@selector(validateHTTPResponse:fromCache:)]) {
        isValid = [self.responseValidator validateHTTPResponse:self.responseObject fromCache:YES];
    }
    
    if (isValid) {
        if (nil != self.delegate && [self.delegate respondsToSelector:@selector(processRequest:success:)]) {
            [self.delegate processRequest:self success:isValid];
        }
        
        if (nil != self.resultBlock) {
            self.resultBlock(self, isValid);
        }
    }
}

- (BOOL)start:(NSError **)error
{
    if (self.shouldIgnoreCache) {
        return [super start:error];
    }
    
    if (nil != self.cacheResponse) {
        if (self.isCacheAvailable) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self cacheRequestCallback];
                self.resultBlock = nil;
            });
            
            return YES;
        }
        else if (self.shouldExpiredCacheValid) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self cacheRequestCallback];
            });
        }
    }

    return [super start:error];
}

- (BOOL)startWithResult:(TCRequestResultBlockType)resultBlock error:(NSError **)error
{
    self.resultBlock = resultBlock;
    return [self start:error];
}

- (BOOL)forceStart:(NSError **)error
{
    self.isForceStart = YES;
    if (nil != self.cacheResponse
        && (self.isCacheAvailable || self.shouldExpiredCacheValid)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self cacheRequestCallback];
        });
    }
    
    return [super start:error];
}

#pragma mark -

- (NSString *)cacheFileName
{
    NSString *requestUrl = nil;
    if (nil != self.requestAgent && [self.requestAgent respondsToSelector:@selector(buildRequestUrlForRequest:)]) {
        requestUrl = [self.requestAgent buildRequestUrlForRequest:self];
    }
    NSParameterAssert(requestUrl);

    NSString *cacheKey = [NSString stringWithFormat:@"Method:%zd RequestUrl:%@ Parames:%@ Sensitive:%@", self.requestMethod, requestUrl, self.parametersForCachePathFilter, _sensitiveDataForCachePathFilter];

    return cacheKey.MD5_32;
}

- (NSString *)cacheFilePath
{
    NSString *path = nil;
    if (nil != self.requestAgent && [self.requestAgent respondsToSelector:@selector(cachePathForResponse)]) {
        path = [self.requestAgent cachePathForResponse];
    }
    
    NSParameterAssert(path);
    [self createDiretoryForCachePath:path];
    return [path stringByAppendingPathComponent:self.cacheFileName];
}

- (void)createDiretoryForCachePath:(NSString *)path
{
    if (nil == path) {
        return;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if ([fileManager fileExistsAtPath:path isDirectory:&isDir]) {
        if (isDir) {
            return;
        }
        else {
            [fileManager removeItemAtPath:path error:NULL];
        }
    }
    
    if ([[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL]) {
        
        [[NSURL fileURLWithPath:path] setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:NULL];
    }
}

@end
