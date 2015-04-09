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


@interface AFURLConnectionOperation (TCHTTPRequest)
@property(nonatomic,strong,readwrite) NSURLRequest *request;
@end

@interface TCHTTPRequest ()

@property(atomic,assign,readwrite) BOOL isCancelled;

@end


@implementation TCHTTPRequest
{
    @private
    BOOL _isDataFromCache;
    
    NSString *_authorizationUsername;
    NSString *_authorizationPassword;
    void *_observer;
}

@dynamic shouldIgnoreCache;
@dynamic shouldCacheResponse;
@dynamic cacheTimeoutInterval;
@dynamic isDataFromCache;
@dynamic shouldExpiredCacheValid;

@synthesize isRetainByRequestPool = _isRetainByRequestPool;


#ifdef DEBUG
- (void)dealloc
{
    NSLog(@"%@", self);
}
#endif

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

- (id)responseObject
{
    return nil != _requestOperation ? _requestOperation.responseObject : nil;
}

- (void)setObserver:(__unsafe_unretained id)observer
{
    _observer = (__bridge void *)(observer);
}

- (void *)observer
{
    if (nil == _observer) {
        self.observer = self.delegate ?: (id)self;
    }
    
    return _observer;
}

- (NSString *)requestIdentifier
{
    if (nil == _requestIdentifier) {
        _requestIdentifier = [NSString stringWithFormat:@"%tu", self.hash];
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

- (id)cacheResponse
{
    return nil;
}

- (void)requestRespondSuccess
{
    
}

- (void)setCachePathFilterWithRequestParameters:(NSDictionary *)parameters
                                  sensitiveData:(id)sensitiveData;
{
    @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:@"for subclass to impl" userInfo:nil];
}


#pragma mark - Custom

- (void)setAuthorizationHeaderFieldWithUsername:(NSString *)username
                                       password:(NSString *)password
{
    _authorizationUsername = [username copy];
    _authorizationPassword = [password copy];
}


#pragma mark - Helper

- (NSString *)description
{
    NSURLRequest *request = self.requestOperation.request;
    return [NSString stringWithFormat:@"🌍🌍🌍 %@: %@\n param: %@", NSStringFromClass(self.class), request.URL, [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]];
}


@end
