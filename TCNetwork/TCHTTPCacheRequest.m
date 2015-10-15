//
//  TCHTTPCacheRequest.m
//  TCKit
//
//  Created by dake on 15/3/16.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import "TCHTTPCacheRequest.h"
#import "TCHTTPRequestHelper.h"


@interface TCHTTPCacheRequest ()

@property (nonatomic, strong) id cachedResponse;

@end

@implementation TCHTTPCacheRequest
{
    @private
    NSDictionary *_parametersForCachePathFilter;
    id _sensitiveDataForCachePathFilter;
}

@dynamic isForceStart;

@synthesize shouldIgnoreCache = _shouldIgnoreCache;
@synthesize shouldCacheResponse = _shouldCacheResponse;
@synthesize cacheTimeoutInterval = _cacheTimeoutInterval;
@synthesize shouldExpiredCacheValid = _shouldExpiredCacheValid;
@synthesize shouldCacheEmptyResponse = _shouldCacheEmptyResponse;


+ (dispatch_queue_t)responseQueue
{
    static dispatch_queue_t s_queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_queue = dispatch_queue_create("TCHTTPCacheRequest", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return s_queue ?: dispatch_get_main_queue();
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _shouldCacheResponse = YES;
        _shouldCacheEmptyResponse = YES;
    }
    return self;
}

- (BOOL)isDataFromCache
{
    return nil != _cachedResponse;
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


- (BOOL)validateResponseObjectForCache
{
    id responseObject = self.responseObject;
    if (nil == responseObject || (NSNull *)responseObject == NSNull.null) {
        return NO;
    }
    
    if (!_shouldCacheEmptyResponse) {
        if ([responseObject isKindOfClass:NSDictionary.class]) {
            return [(NSDictionary *)responseObject count] > 0;
        }
        else if ([responseObject isKindOfClass:NSArray.class]) {
            return [(NSArray *)responseObject count] > 0;
        }
        else if ([responseObject isKindOfClass:NSString.class]) {
            return [(NSString *)responseObject length] > 0;
        }
    }
    
    return YES;
}

- (void)requestResponseReset
{
    if (self.requestMethod == kTCHTTPRequestMethodDownload) {
        // delete tmp download file
        [[NSFileManager defaultManager] removeItemAtPath:self.tmpFilePath error:NULL];
    }
    _cachedResponse = nil;
}

- (void)requestResponded:(BOOL)isValid finish:(dispatch_block_t)finish
{
    // !!!: must be called before self.validateResponseObject called, below
    [self requestResponseReset];
    
    if (isValid) {
        __weak typeof(self) wSelf = self;
        dispatch_async(self.class.responseQueue, ^{
            @autoreleasepool {
                __strong typeof(wSelf) sSelf = wSelf;
                
                if (sSelf.requestMethod != kTCHTTPRequestMethodDownload && sSelf.shouldCacheResponse && sSelf.cacheTimeoutInterval != 0 && sSelf.validateResponseObjectForCache) {
                    NSString *path = sSelf.cacheFilePath;
                    if (nil != path && ![NSKeyedArchiver archiveRootObject:sSelf.responseObject toFile:path]) {
                        NSAssert(false, @"write response failed.");
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sSelf callSuperRequestResponded:isValid finish:finish];
                });
            }
        });
    }
    else {
        [super requestResponded:isValid finish:finish];
    }
}

- (void)callSuperRequestResponded:(BOOL)isValid finish:(dispatch_block_t)finish
{
    [super requestResponded:isValid finish:finish];
}


#pragma mark -

- (void)cachedResponseWithoutValidate:(void(^)(id response))result
{
    if (nil == result) {
        return;
    }
    
    if (nil == _cachedResponse) {
        NSString *path = self.cacheFilePath;
        if (nil == path) {
            result(nil);
            return;
        }
        
        NSFileManager *fileMngr = NSFileManager.defaultManager;
        BOOL isDir = NO;
        if (![fileMngr fileExistsAtPath:path isDirectory:&isDir] || isDir) {
            result(nil);
            return;
        }
        
        __weak typeof(self) wSelf = self;
        if (self.requestMethod == kTCHTTPRequestMethodDownload) {
            // copy download file to tmp file
            NSString *tmpPath = self.tmpFilePath;
            if ([fileMngr fileExistsAtPath:tmpPath]) {
                _cachedResponse = tmpPath;
                result(_cachedResponse);
            }
            else {
                dispatch_async(self.class.responseQueue, ^{
                    @autoreleasepool {
                        if ([fileMngr copyItemAtPath:path toPath:tmpPath error:NULL]) {
                            __strong typeof(wSelf) sSelf = wSelf;
                            dispatch_async(dispatch_get_main_queue(), ^{
                                sSelf.cachedResponse = tmpPath;
                                result(tmpPath);
                            });
                        }
                    }
                });
            }
        }
        else {
            dispatch_async(self.class.responseQueue, ^{
                @autoreleasepool {
                    id cachedResponse = nil;
                    @try {
                        cachedResponse = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
                    }
                    @catch (NSException *exception) {
                        cachedResponse = nil;
                        NSLog(@"%@", exception);
                    }
                    @finally {
                        __strong typeof(wSelf) sSelf = wSelf;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            sSelf.cachedResponse = cachedResponse;
                            result(cachedResponse);
                        });
                    }
                }
            });
        }
    }
    else {
        result(_cachedResponse);
    }
}

- (void)cachedResponseByForce:(BOOL)force result:(void(^)(id response, TCHTTPCachedResponseState state))result
{
    if (nil == result) {
        return;
    }
    
    TCHTTPCachedResponseState cacheState = self.cacheState;
    
    if (cacheState == kTCHTTPCachedResponseStateValid || (force && cacheState != kTCHTTPCachedResponseStateNone)) {
        __weak typeof(self) wSelf = self;
        [self cachedResponseWithoutValidate:^(id response) {
            if (nil != response && nil != wSelf.responseValidator && [wSelf.responseValidator respondsToSelector:@selector(validateHTTPResponse:fromCache:)]) {
                [wSelf.responseValidator validateHTTPResponse:response fromCache:YES];
            }
            
            result(response, cacheState);
        }];
        
        return;
    }

    result(nil, cacheState);
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
            if (![fileMngr fileExistsAtPath:path]) {
                return kTCHTTPCachedResponseStateNone;
            }
        }
        
        return kTCHTTPCachedResponseStateValid;
    }
    else {
        return kTCHTTPCachedResponseStateExpired;
    }
}

- (void)cacheRequestCallbackWithoutFiring:(BOOL)notFire
{
    BOOL isValid = YES;
    if (nil != self.responseValidator && [self.responseValidator respondsToSelector:@selector(validateHTTPResponse:fromCache:)]) {
        isValid = [self.responseValidator validateHTTPResponse:self.responseObject fromCache:YES];
    }
    
    if (notFire) {
        __weak typeof(self) wSelf = self;
        [super requestResponded:isValid finish:^{
            // remove from pool
            if (wSelf.isRetainByRequestPool) {
                [wSelf.requestAgent removeRequestObserver:wSelf.observer forIdentifier:wSelf.requestIdentifier];
            }
        }];
    }
    else if (isValid) {
        [super requestResponded:isValid finish:nil];
    }
}

- (BOOL)callSuperStart
{
    return [super start:NULL];
}

- (BOOL)start:(NSError **)error
{
    if (self.shouldIgnoreCache) {
        return [super start:error];
    }
    
    TCHTTPCachedResponseState state = self.cacheState;
    if (state == kTCHTTPCachedResponseStateValid || (self.shouldExpiredCacheValid && state != kTCHTTPCachedResponseStateNone)) {
        // !!!: add to pool to prevent self dealloc before cache respond
        [self.requestAgent addObserver:self.observer forRequest:self];
        __weak typeof(self) wSelf = self;
        [self cachedResponseWithoutValidate:^(id response) {
            
            if (nil == response) {
                [wSelf callSuperStart];
                return;
            }
            
            __strong typeof(wSelf) sSelf = wSelf;
            if (kTCHTTPCachedResponseStateValid == state) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sSelf cacheRequestCallbackWithoutFiring:YES];
                    sSelf.resultBlock = nil;
                    sSelf.downloadProgressBlock = nil;
                });
            }
            else if (wSelf.shouldExpiredCacheValid) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sSelf cacheRequestCallbackWithoutFiring:![sSelf callSuperStart]];
                });
            }
        }];
        
        return kTCHTTPCachedResponseStateValid == state ? YES : [super canStart:error];
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
    
    TCHTTPCachedResponseState state = self.cacheState;
    if (!self.shouldIgnoreCache
        && (kTCHTTPCachedResponseStateExpired == state || kTCHTTPCachedResponseStateValid == state)) {
        // !!!: add to pool to prevent self dealloc before cache respond
        [self.requestAgent addObserver:self.observer forRequest:self];
        
        __weak typeof(self) wSelf = self;
        [self cachedResponseWithoutValidate:^(id response) {
            __strong typeof(wSelf) sSelf = wSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL ret = [sSelf callSuperStart];
                if (nil != response) {
                    [sSelf cacheRequestCallbackWithoutFiring:!ret];
                }
            });
        }];
        
        return [super canStart:error];
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

    return [TCHTTPRequestHelper MD5_32:cacheKey];
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
