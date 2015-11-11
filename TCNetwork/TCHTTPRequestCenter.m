//
//  TCHTTPRequestCenter.m
//  TCKit
//
//  Created by dake on 15/3/16.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import "TCHTTPRequestCenter.h"
#import "AFHTTPRequestOperationManager.h"
#import "AFDownloadRequestOperation.h"
#import "TCHTTPRequestHelper.h"

#import "TCHTTPRequest+Public.h"
#import "TCBaseResponseValidator.h"


@implementation TCHTTPRequestCenter
{
@private
    AFHTTPRequestOperationManager *_requestManager;
    NSMutableDictionary *_requestPool;
    NSString *_cachePathForResponse;
    Class _responseValidorClass;
}

+ (instancetype)defaultCenter
{
    static id s_defaultCenter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_defaultCenter = [[self alloc] initWithBaseURL:nil];
    });
    
    return s_defaultCenter;
}

- (Class)responseValidorClass
{
    return _responseValidorClass ?: TCBaseResponseValidator.class;
}

- (void)registerResponseValidatorClass:(Class)validatorClass
{
    _responseValidorClass = validatorClass;
}

- (BOOL)networkReachable
{
    return self.requestManager.reachabilityManager.reachable;
}

- (NSInteger)maxConcurrentOperationCount
{
    return self.requestManager.operationQueue.maxConcurrentOperationCount;
}

- (void)setMaxConcurrentOperationCount:(NSInteger)maxConcurrentOperationCount
{
    @synchronized(self.requestManager.operationQueue) {
        self.requestManager.operationQueue.maxConcurrentOperationCount = maxConcurrentOperationCount;
    }
}

- (NSString *)cachePathForResponse
{
    if (nil == _cachePathForResponse) {
        NSString *pathOfLibrary = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
        _cachePathForResponse = [pathOfLibrary stringByAppendingPathComponent:@"TCHTTPRequestCache"];
    }
    
    return _cachePathForResponse;
}

- (AFSecurityPolicy *)securityPolicy
{
    return _requestManager.securityPolicy;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        _requestPool = [NSMutableDictionary dictionary];
    }
    return self;
}

- (AFHTTPRequestOperationManager *)requestManager
{
    @synchronized(self) {
        if (nil == _requestManager) {
            
            _requestManager = [[AFHTTPRequestOperationManager alloc] init];
            [_requestManager.reachabilityManager startMonitoring];
            AFSecurityPolicy *policy = self.securityPolicy;
            if (nil != policy) {
                _requestManager.securityPolicy = policy;
            }
        }
    }
    
    return _requestManager;
}

- (instancetype)initWithBaseURL:(NSURL *)url
{
    self = [self init];
    if (self) {
        _baseURL = url;
    }
    return self;
}


- (BOOL)canAddRequest:(TCHTTPRequest *)request error:(NSError **)error
{
    NSParameterAssert(request.observer);
    
    if (nil == request.observer) {
        if (NULL != error) {
            *error = [NSError errorWithDomain:NSStringFromClass(request.class)
                                         code:-1
                                     userInfo:@{NSLocalizedFailureReasonErrorKey: @"Callback Error",
                                                NSLocalizedDescriptionKey: @"delegate or resultBlock of request must be set"}];
        }
        return NO;
    }
    
    NSDictionary *headerFieldValueDic = self.customHeaderValue;
    for (NSString *httpHeaderField in headerFieldValueDic.allKeys) {
        NSString *value = headerFieldValueDic[httpHeaderField];
        if (![httpHeaderField isKindOfClass:NSString.class] || ![value isKindOfClass:NSString.class]) {
            if (NULL != error) {
                *error = [NSError errorWithDomain:NSStringFromClass(request.class)
                                             code:-1
                                         userInfo:@{NSLocalizedFailureReasonErrorKey: @"HTTP HEAD Error",
                                                    NSLocalizedDescriptionKey: @"class of key/value in headerFieldValueDictionary should be NSString."}];
            }
            
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)addRequest:(TCHTTPRequest *)request error:(NSError **)error
{
    if (![self canAddRequest:request error:error]) {
        return NO;
    }
    
    AFHTTPRequestOperationManager *requestMgr = self.requestManager;
    @synchronized(requestMgr) {
        
        if (request.serializerType == kTCHTTPRequestSerializerTypeHTTP) {
            requestMgr.requestSerializer = [AFHTTPRequestSerializer serializer];
        }
        else if (request.serializerType == kTCHTTPRequestSerializerTypeJSON) {
            requestMgr.requestSerializer = [AFJSONRequestSerializer serializer];
        }
        
        
        if (nil != self.acceptableContentTypes) {
            NSMutableSet *set = requestMgr.responseSerializer.acceptableContentTypes.mutableCopy;
            [set unionSet:self.acceptableContentTypes];
            requestMgr.responseSerializer.acceptableContentTypes = set;
        }
        
        requestMgr.requestSerializer.timeoutInterval = MAX(self.timeoutInterval, request.timeoutInterval);
        
        // if api need server username and password
        if (self.authorizationUsername.length > 0) {
            [requestMgr.requestSerializer setAuthorizationHeaderFieldWithUsername:self.authorizationUsername password:self.authorizationPassword];
        }
        else {
            [requestMgr.requestSerializer clearAuthorizationHeader];
        }
        
        // if api need add custom value to HTTPHeaderField
        NSDictionary *headerFieldValueDic = self.customHeaderValue;
        for (NSString *httpHeaderField in headerFieldValueDic.allKeys) {
            NSString *value = headerFieldValueDic[httpHeaderField];
            [requestMgr.requestSerializer setValue:value forHTTPHeaderField:httpHeaderField];
        }
        
        AFHTTPRequestOperation *operation = [self requestOperationFor:request requestManager:requestMgr];
        if (nil != operation) {
            
            request.requestOperation = operation;
            request.state = kTCHTTPRequestStateExecuting;
            // add to pool
            [self addObserver:request.observer forRequest:request];
        }
        else {
            if (nil != request.responseValidator) {
                request.responseValidator.error = [NSError errorWithDomain:NSStringFromClass(request.class)
                                                                      code:-1
                                                                  userInfo:@{NSLocalizedFailureReasonErrorKey: @"Fire Request error",
                                                                             NSLocalizedDescriptionKey: @"generate AFHTTPRequestOperation instances failed."}];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [request requestResponded:NO finish:nil clean:YES];
            });
        }
        
        return YES;
    }
}


- (AFHTTPRequestOperation *)requestOperationFor:(TCHTTPRequest *)request requestManager:(AFHTTPRequestOperationManager *)requestMgr
{
    AFHTTPRequestOperation *operation = nil;
    
    void (^successBlock)() = ^{
        [self handleRequestResult:request success:YES error:nil];
    };
    void (^failureBlock)() = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleRequestResult:request success:NO error:error];
    };
    
    // if api build custom url request
    NSURLRequest *customUrlRequest = request.customUrlRequest;
    
    if (nil != customUrlRequest) {
        operation = [[AFHTTPRequestOperation alloc] initWithRequest:customUrlRequest];
        [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
        [requestMgr.operationQueue addOperation:operation];
        return operation;
    }
    
    
    NSString *url = [self buildRequestUrlForRequest:request];
    NSParameterAssert(url);
    
    NSDictionary *param = request.parameters;
    if ([self.urlFilter respondsToSelector:@selector(filteredParamForParam:)]) {
        param = [self.urlFilter filteredParamForParam:param];
    }
    
    switch (request.requestMethod) {
            
        case kTCHTTPRequestMethodDownload: {
            NSParameterAssert(request.downloadTargetPath);
            NSString *downloadUrl = [TCHTTPRequestHelper urlString:url appendParameters:param];
            NSParameterAssert(downloadUrl);
            
            if (nil != downloadUrl && request.downloadTargetPath.length > 0) {
                NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:downloadUrl]
                                                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                        timeoutInterval:self.requestManager.requestSerializer.timeoutInterval];
                
                operation = [[AFDownloadRequestOperation alloc] initWithRequest:urlRequest
                                                                 fileIdentifier:request.downloadIdentifier
                                                                     targetPath:request.downloadTargetPath
                                                                   shouldResume:request.shouldResumeDownload];
                
                [(AFDownloadRequestOperation *)operation setProgressiveDownloadProgressBlock:request.downloadProgressBlock];
                [(AFDownloadRequestOperation *)operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
                [self.requestManager.operationQueue addOperation:operation];
                
                request.downloadProgressBlock = nil;
            }
            break;
        }
            
        case kTCHTTPRequestMethodGet: {
            operation = [self.requestManager GET:url parameters:param success:successBlock failure:failureBlock];
            break;
        }
            
        case kTCHTTPRequestMethodPost: {
            
            if (nil != request.constructingBodyBlock) {
                operation = [self.requestManager POST:url parameters:param constructingBodyWithBlock:request.constructingBodyBlock success:successBlock failure:failureBlock];
                request.constructingBodyBlock = nil;
            }
            else {
                operation = [self.requestManager POST:url parameters:param success:successBlock failure:failureBlock];
            }
            break;
        }
            
        case kTCHTTPRequestMethodHead: {
            operation = [self.requestManager HEAD:url parameters:param success:successBlock failure:failureBlock];
            break;
        }
            
        case kTCHTTPRequestMethodPut: {
            operation = [self.requestManager PUT:url parameters:param success:successBlock failure:failureBlock];
            break;
        }
            
        case kTCHTTPRequestMethodDelete: {
            operation = [self.requestManager DELETE:url parameters:param success:successBlock failure:failureBlock];
            break;
        }
            
        case kTCHTTPRequestMethodPatch: {
            operation = [self.requestManager PATCH:url parameters:param success:successBlock failure:failureBlock];
            break;
        }
            
        default:
            break;
    }
    
    return operation;
}


#pragma mark - TCHTTPRequestCenterProtocol

- (void)addObserver:(__unsafe_unretained id)observer forRequest:(id<TCHTTPRequestProtocol>)request
{
    if (request.isRetainByRequestPool) {
        return;
    }
    
    NSNumber *key = @((NSUInteger)observer);
    
    @synchronized(_requestPool) {
        NSParameterAssert(request);
        
        
        NSMutableDictionary *dic = _requestPool[key];
        if (nil == dic) {
            dic = [NSMutableDictionary dictionary];
            _requestPool[key] = dic;
        }
        
        id<TCHTTPRequestProtocol> preRequest = dic[request.requestIdentifier];
        if (nil != preRequest && preRequest.isRetainByRequestPool) {
            preRequest.isRetainByRequestPool = NO;
            [preRequest cancel];
        }
        
        request.isRetainByRequestPool = YES;
        dic[request.requestIdentifier] = request;
    }
}

- (void)removeRequestObserver:(__unsafe_unretained id)observer forIdentifier:(id<NSCopying>)identifier
{
    NSNumber *key = @((NSUInteger)(__bridge void *)(observer));
    @synchronized(_requestPool) {
        
        NSMutableDictionary *dic = _requestPool[key];
        
        if (nil != identifier) {
            id<TCHTTPRequestProtocol> request = dic[identifier];
            if (nil != request && request.isRetainByRequestPool) {
                request.isRetainByRequestPool = NO;
                [request cancel];
                [dic removeObjectForKey:identifier];
                if (dic.count < 1) {
                    [_requestPool removeObjectForKey:key];
                }
            }
        }
        else {
            [dic.allValues setValue:@NO forKeyPath:@"isRetainByRequestPool"];
            [dic.allValues makeObjectsPerformSelector:@selector(cancel)];
            [_requestPool removeObjectForKey:key];
        }
    }
}

- (void)removeRequestObserver:(__unsafe_unretained id)observer
{
    [self removeRequestObserver:observer forIdentifier:nil];
}

- (void)removeAllCachedResponse
{
    NSString *path = self.cachePathForResponse;
    if (nil != path) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    }
}


#pragma mark -

- (NSString *)buildRequestUrlForRequest:(id<TCHTTPRequestProtocol>)request
{
    NSString *queryUrl = request.apiUrl;
    
    if (nil != self.urlFilter) {
        if ([self.urlFilter respondsToSelector:@selector(filteredUrlForUrl:)]) {
            queryUrl = [self.urlFilter filteredUrlForUrl:queryUrl];
        }
    }
    
    if ([queryUrl.lowercaseString hasPrefix:@"http"]) {
        return queryUrl;
    }
    
    NSURL *baseUrl = nil;
    
    if (request.shouldUseCDN) {
        if (request.cdnUrl.length > 0) {
            baseUrl = [NSURL URLWithString:request.cdnUrl];
        }
        else {
            baseUrl = self.cdnURL ?: self.baseURL;
        }
    }
    else {
        if (request.baseUrl.length > 0) {
            baseUrl = [NSURL URLWithString:request.baseUrl];
        }
        else {
            baseUrl = self.baseURL;
        }
    }
    return [baseUrl URLByAppendingPathComponent:queryUrl].absoluteString;
}

- (id<TCHTTPResponseValidator>)responseValidatorForRequest:(id<TCHTTPRequestProtocol>)request
{
    return request.requestMethod != kTCHTTPRequestMethodDownload ? [[self.responseValidorClass alloc] init] : nil;
}


#pragma mark - 

- (void)handleRequestResult:(id<TCHTTPRequestProtocol>)request success:(BOOL)success error:(NSError *)error
{
    dispatch_block_t block = ^{
        request.state = kTCHTTPRequestStateFinished;
        [request requestResponseReset];
        
        BOOL isValid = success;
        
        if (nil != request.responseValidator) {
            if (isValid) {
                if ([request.responseValidator respondsToSelector:@selector(validateHTTPResponse:fromCache:)]) {
                    isValid = [request.responseValidator validateHTTPResponse:request.responseObject fromCache:NO];
                }
            }
            else {
                
                if ([request.responseValidator respondsToSelector:@selector(reset)]) {
                    [request.responseValidator reset];
                }
                request.responseValidator.error = error;
            }
        }

        [request requestResponded:isValid finish:^{
            // remove from pool
            if (request.isRetainByRequestPool) {
                [self removeRequestObserver:request.observer forIdentifier:request.requestIdentifier];
            }
        } clean:YES];
    };
    
    if (NSThread.isMainThread) {
        block();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

#pragma mark - Making HTTP Requests

- (TCHTTPRequest *)requestWithMethod:(TCHTTPRequestMethod)method apiUrl:(NSString *)apiUrl host:(NSString *)host cache:(BOOL)cache
{
    if (cache) {
        return [self cacheRequestWithMethod:method apiUrl:apiUrl host:host];
    }
    else {
        return [self requestWithMethod:method apiUrl:apiUrl host:host];
    }
}

- (TCHTTPRequest *)requestWithMethod:(TCHTTPRequestMethod)method apiUrl:(NSString *)apiUrl host:(NSString *)host
{
    TCHTTPRequest *request = [TCHTTPRequest requestWithMethod:method];
    request.requestAgent = self;
    request.apiUrl = apiUrl;
    request.baseUrl = host;
    
    return request;
}

- (TCHTTPRequest *)cacheRequestWithMethod:(TCHTTPRequestMethod)method apiUrl:(NSString *)apiUrl host:(NSString *)host
{
    TCHTTPRequest *request = [TCHTTPRequest cacheRequestWithMethod:method];
    request.requestAgent = self;
    request.apiUrl = apiUrl;
    request.baseUrl = host;
    
    return request;
}

- (TCHTTPRequest *)batchRequestWithRequests:(NSArray *)requests
{
    NSParameterAssert(requests);
    TCHTTPRequest *request = [TCHTTPRequest batchRequestWithRequests:requests];
    request.requestAgent = self;
    
    return request;
}

- (TCHTTPRequest *)requestForDownload:(NSString *)url to:(NSString *)dstPath cache:(BOOL)cache
{
    NSParameterAssert(url);
    NSParameterAssert(dstPath);
    
    if (nil == url || nil == dstPath) {
        return nil;
    }
    
    TCHTTPRequest *request = [self requestWithMethod:kTCHTTPRequestMethodDownload apiUrl:url host:nil cache:cache];
    request.downloadTargetPath = dstPath;
    
    return request;
}


@end
