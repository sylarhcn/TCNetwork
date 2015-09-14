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
    id _cachedResponse;
}

@dynamic isForceStart;

@synthesize shouldIgnoreCache = _shouldIgnoreCache;
@synthesize shouldCacheResponse = _shouldCacheResponse;
@synthesize cacheTimeoutInterval = _cacheTimeoutInterval;
@synthesize shouldExpiredCacheValid = _shouldExpiredCacheValid;


- (instancetype)init
{
    self = [super init];
    if (self) {
        self.shouldCacheResponse = YES;
    }
    return self;
}

- (BOOL)isDataFromCache
{
    return nil != _cachedResponse;
}

- (id)cachedResponseWithoutValidate
{
    if (nil == _cachedResponse) {
        NSString *path = self.cacheFilePath;
        if (nil == path) {
            return nil;
        }
        
        NSFileManager *fileMngr = NSFileManager.defaultManager;
        BOOL isDir = NO;
        if (![fileMngr fileExistsAtPath:path isDirectory:&isDir] || isDir) {
            return nil;
        }
        
        @try {
            if (self.requestMethod != kTCHTTPRequestMethodDownload) {
                _cachedResponse = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
            }
            else {
               // copy download file to tmp file
                NSString *tmpPath = self.tmpFilePath;
                if ([fileMngr fileExistsAtPath:tmpPath]) {
                    _cachedResponse = tmpPath;
                }
                else if ([fileMngr copyItemAtPath:path toPath:tmpPath error:NULL]) {
                    _cachedResponse = tmpPath;
                }
            }
        }
        @catch (NSException *exception) {
            NSLog(@"%@", exception);
        }
    }
    
    return _cachedResponse;
}

- (id)cachedResponseByForce:(BOOL)force state:(TCHTTPCachedResponseState *)state
{
    TCHTTPCachedResponseState cacheState = self.cacheState;
    if (NULL != state) {
        *state = cacheState;
    }
    
    if (cacheState == kTCHTTPCachedResponseStateValid || (force && cacheState != kTCHTTPCachedResponseStateNone)) {
        return self.cachedResponseWithoutValidate;
    }
    
    return nil;
}

- (void)clearCachedResponse
{
    [self requestRespondReset];
}

- (id<NSCoding>)responseObject
{
    if (nil != _cachedResponse) {
        return _cachedResponse;
    }
    return [super responseObject];
}

- (NSDictionary *)parametersForCachePathFilter
{
    return _parametersForCachePathFilter ?: self.parameters;
}

- (void)setCachePathFilterWithRequestParameters:(NSDictionary *)parameters
                                  sensitiveData:(NSObject<NSCopying> *)sensitiveData;
{
    _parametersForCachePathFilter = parameters.copy;
    _sensitiveDataForCachePathFilter = sensitiveData.copy;
}


- (BOOL)validateResponseObject
{
    id responseObject = self.responseObject;
    if (nil == responseObject || (NSNull *)responseObject == NSNull.null) {
        return NO;
    }
    
    if ([responseObject isKindOfClass:NSDictionary.class]) {
        return [(NSDictionary *)responseObject count] > 0;
    }
    
    return YES;
}

- (void)requestRespondReset
{
    [super requestRespondReset];
    
    if (self.requestMethod == kTCHTTPRequestMethodDownload) {
        // delete tmp download file
        [[NSFileManager defaultManager] removeItemAtPath:self.tmpFilePath error:NULL];
    }
    _cachedResponse = nil;
}

- (void)requestRespondSuccess
{
    [super requestRespondSuccess];
    
    // !!!: must be called before self.validateResponseObject called, below
    [self clearCachedResponse];
    
    if (self.requestMethod != kTCHTTPRequestMethodDownload && self.shouldCacheResponse && self.cacheTimeoutInterval != 0 && self.validateResponseObject) {
        NSString *path = self.cacheFilePath;
        if (nil != path
            && ![NSKeyedArchiver archiveRootObject:self.responseObject toFile:path]) {
            NSAssert(false, @"write response failed.");
        }
    }
}

- (void)requestRespondFailed
{
    [super requestRespondFailed];
    [self requestRespondReset];
}

- (TCHTTPCachedResponseState)cacheState
{
    NSString *path = self.cacheFilePath;
    if (nil == path) {
        return kTCHTTPCachedResponseStateNone;
    }
    
    BOOL isDir = NO;
    NSFileManager *fileMngr = NSFileManager.defaultManager;
    if (![fileMngr fileExistsAtPath:path isDirectory:&isDir] || isDir) {
        return kTCHTTPCachedResponseStateNone;
    }
    
    NSDictionary *attributes = [fileMngr attributesOfItemAtPath:path error:NULL];
    
    if (nil != attributes && (self.cacheTimeoutInterval < 0 || -attributes.fileModificationDate.timeIntervalSinceNow < self.cacheTimeoutInterval)) {
        if (self.requestMethod == kTCHTTPRequestMethodDownload) {
            [self cachedResponseWithoutValidate];
            if (nil == _cachedResponse || ![_cachedResponse isKindOfClass:NSString.class] || ![fileMngr fileExistsAtPath:_cachedResponse]) {
                return kTCHTTPCachedResponseStateNone;
            }
        }
        
        return kTCHTTPCachedResponseStateValid;
    }
    else {
        return kTCHTTPCachedResponseStateExpired;
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
    
    if (nil != self.cachedResponseWithoutValidate) {
        if (kTCHTTPCachedResponseStateValid == self.cacheState) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self cacheRequestCallback];
                self.resultBlock = nil;
                self.downloadProgressBlock = nil;
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
    if (!self.shouldIgnoreCache
        && (self.shouldExpiredCacheValid || kTCHTTPCachedResponseStateValid == self.cacheState)
        && nil != self.cachedResponseWithoutValidate) {
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
    if (self.requestMethod == kTCHTTPRequestMethodDownload) {
        return self.downloadTargetPath;
    }
    
    NSString *path = nil;
    if (nil != self.requestAgent && [self.requestAgent respondsToSelector:@selector(cachePathForResponse)]) {
        path = [self.requestAgent cachePathForResponse];
    }
    
    NSParameterAssert(path);
    if ([self createDiretoryForCachePath:path]) {
        return [path stringByAppendingPathComponent:self.cacheFileName];
    }
    
    return nil;
}

- (NSString *)tmpFilePath
{
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"TCHTTPRequestCache"];
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:dir
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:NULL]) {
        NSAssert(false, @"create directory failed.");
        dir = nil;
    }

    return [dir stringByAppendingPathComponent:self.cacheFileName];
}

- (BOOL)createDiretoryForCachePath:(NSString *)path
{
    if (nil == path) {
        return NO;
    }
    
    NSFileManager *fileManager = NSFileManager.defaultManager;
    BOOL isDir = NO;
    if ([fileManager fileExistsAtPath:path isDirectory:&isDir]) {
        if (isDir) {
            return YES;
        }
        else {
            [fileManager removeItemAtPath:path error:NULL];
        }
    }
    
    if ([fileManager createDirectoryAtPath:path
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:NULL]) {
        
        [[NSURL fileURLWithPath:path] setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:NULL];
        return YES;
    }
    
    return NO;
}

@end
