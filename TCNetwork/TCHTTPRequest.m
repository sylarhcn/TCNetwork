//
//  TCHTTPRequest.m
//  TCKit
//
//  Created by dake on 15/3/15.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import "TCHTTPRequest.h"
#import "AFHTTPRequestOperation.h"
#import "TCHTTPRequestHelper.h"


NSInteger const kTCHTTPRequestCacheNeverExpired = -1;


@interface AFURLConnectionOperation (TCHTTPRequest)
@property (nonatomic, strong, readwrite) NSURLRequest *request;
@end

@interface TCHTTPRequest ()

@property (atomic, assign, readwrite) BOOL isCancelled;

@end


@implementation TCHTTPRequest
{
    @private
    NSString *_authorizationUsername;
    NSString *_authorizationPassword;
    void *_observer;
}

@dynamic shouldIgnoreCache;
@dynamic shouldCacheResponse;
@dynamic cacheTimeoutInterval;
@dynamic shouldExpiredCacheValid;
@dynamic shouldCacheEmptyResponse;

@synthesize isForceStart = _isForceStart;
@synthesize isRetainByRequestPool = _isRetainByRequestPool;


- (instancetype)init
{
    self = [super init];
    if (self) {
        _timeoutInterval = 60.0f;
    }
    return self;
}

- (instancetype)initWithMethod:(TCHTTPRequestMethod)method
{
    self = [self init];
    if (self) {
        _requestMethod = method;
    }
    return self;
}

- (BOOL)isExecuting
{
    return kTCHTTPRequestStateExecuting == _state;
}

- (id<NSCoding>)responseObject
{
    return nil != _requestOperation ? ((id<NSCoding>)_requestOperation.responseObject) : nil;
}

- (void)setObserver:(__unsafe_unretained id)observer
{
    _observer = (__bridge void *)(observer);
}

- (void *)observer
{
    if (NULL == _observer) {
        self.observer = self.delegate ?: (id)self;
    }
    
    return _observer;
}

- (NSString *)requestIdentifier
{
    if (nil == _requestIdentifier) {
        _requestIdentifier = [NSString stringWithFormat:@"%p_%@_%zd", self.observer, self.apiUrl, self.requestMethod].MD5_16;
    }
    
    return _requestIdentifier;
}

- (NSString *)downloadIdentifier
{
    if (nil == _downloadIdentifier) {
        _downloadIdentifier = self.apiUrl.MD5_16;
    }
    
    return _downloadIdentifier;
}

- (id<TCHTTPResponseValidator>)responseValidator
{
    if (nil == _responseValidator
        && nil != self.requestAgent
        && [self.requestAgent respondsToSelector:@selector(responseValidatorForRequest:)]) {
        _responseValidator = [self.requestAgent responseValidatorForRequest:self];
    }
    
    return _responseValidator;
}


- (BOOL)canStart:(NSError **)error
{
    NSParameterAssert(self.requestAgent);
    
    if (nil != self.requestAgent && [self.requestAgent respondsToSelector:@selector(canAddRequest:error:)]) {
        return [self.requestAgent canAddRequest:self error:error];
    }
    
    return NO;
}


- (BOOL)start:(NSError **)error
{
    NSParameterAssert(self.requestAgent);
    
    if (nil != self.requestAgent && [self.requestAgent respondsToSelector:@selector(addRequest:error:)]) {
        return [self.requestAgent addRequest:self error:error];
    }
    
    return NO;
}

- (BOOL)startWithResult:(TCRequestResultBlockType)resultBlock error:(NSError **)error
{
    self.resultBlock = resultBlock;
    return [self start:error];
}

- (BOOL)forceStart:(NSError **)error
{
    self.isForceStart = YES;
    return [self start:error];
}

- (void)cancel
{
    if (_requestOperation.isExecuting && !self.isCancelled) {
        self.isCancelled = YES;
        [_requestOperation cancel];
    }
}


#pragma mark - Batch

- (NSArray *)requestArray
{
    return nil;
}


#pragma mark - Cache

- (BOOL)isCacheValid
{
    return self.cacheState == kTCHTTPCachedResponseStateValid;
}

- (TCHTTPCachedResponseState)cacheState
{
    return kTCHTTPCachedResponseStateNone;
}

- (BOOL)shouldIgnoreCache
{
    return YES;
}

- (BOOL)shouldCacheResponse
{
    return NO;
}

- (NSTimeInterval)cacheTimeoutInterval
{
    return 0.0f;
}

- (BOOL)isDataFromCache
{
    return NO;
}

- (void)cachedResponseByForce:(BOOL)force result:(void(^)(id response, TCHTTPCachedResponseState state))result
{
    
}

- (void)requestResponded:(BOOL)isValid finish:(dispatch_block_t)finish
{
#ifndef TC_IOS_PUBLISH
    if (!isValid) {
        NSLog(@"%@\n \nERROR: %@", self, self.responseValidator.error);
    }
#endif
    
    __weak typeof(self) wSelf = self;
    dispatch_block_t block = ^{
        if (nil != wSelf.delegate && [wSelf.delegate respondsToSelector:@selector(processRequest:success:)]) {
            [wSelf.delegate processRequest:wSelf success:isValid];
        }

        if (nil != wSelf.resultBlock) {
            wSelf.resultBlock(wSelf, isValid);
            wSelf.resultBlock = nil;
        }
        
        if (nil != finish) {
            finish();
        }
    };
    
    if (NSThread.isMainThread) {
        block();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)requestResponseReset
{
    
}

- (void)setCachePathFilterWithRequestParameters:(NSDictionary *)parameters
                                  sensitiveData:(NSObject<NSCopying> *)sensitiveData;
{
    @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:@"for subclass to impl" userInfo:nil];
}


#pragma mark - Custom

- (void)setAuthorizationHeaderFieldWithUsername:(NSString *)username
                                       password:(NSString *)password
{
    _authorizationUsername = username.copy;
    _authorizationPassword = password.copy;
}

- (NSString *)username
{
    return _authorizationUsername;
}

- (NSString *)password
{
    return _authorizationPassword;
}

#pragma mark - Helper

- (NSString *)description
{
    NSURLRequest *request = self.requestOperation.request;
    return [NSString stringWithFormat:@"🌍🌍🌍 %@: %@\n param: %@\n response: %@", NSStringFromClass(self.class), request.URL, [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding], self.responseObject];
}


@end
