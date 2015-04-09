//
//  TCHTTPRequestCenter.m
//  TCKit
//
//  Created by dake on 15/3/16.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import "TCHTTPRequestCenter.h"
#import "AFHTTPRequestOperationManager.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "AFDownloadRequestOperation.h"
#import "TCHTTPRequestHelper.h"

#import "TCHTTPRequest+Public.h"


@implementation TCHTTPRequestCenter
{
@private
    AFHTTPRequestOperationManager *_requestManager;
    NSMutableDictionary *_requestPool;
    NSString *_cachePathForResponse;
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


- (BOOL)networkReachable
{
    return _requestManager.reachabilityManager.reachable;
}

- (NSInteger)maxConcurrentOperationCount
{
    return _requestManager.operationQueue.maxConcurrentOperationCount;
}

- (void)setMaxConcurrentOperationCount:(NSInteger)maxConcurrentOperationCount
{
    @synchronized(_requestManager.operationQueue) {
        _requestManager.operationQueue.maxConcurrentOperationCount = maxConcurrentOperationCount;
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


- (instancetype)init
{
    self = [super init];
    if (self) {
        _requestPool = [NSMutableDictionary dictionary];
        
        [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
        _requestManager = [AFHTTPRequestOperationManager manager];
        [_requestManager.reachabilityManager startMonitoring];
    }
    return self;
}

- (instancetype)initWithBaseURL:(NSURL *)url
{
    self = [self init];
    if (self) {
        _baseURL = url;
    }
    return self;
}


- (BOOL)addRequest:(TCHTTPRequest *)request error:(NSError **)error
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
    
    @synchronized(_requestManager) {
        
        if (request.serializerType == kTCHTTPRequestSerializerTypeHTTP) {
            _requestManager.requestSerializer = [AFHTTPRequestSerializer serializer];
        }
        else if (request.serializerType == kTCHTTPRequestSerializerTypeJSON) {
            _requestManager.requestSerializer = [AFJSONRequestSerializer serializer];
        }
        
        _requestManager.requestSerializer.timeoutInterval = MAX(self.timeoutInterval, request.timeoutInterval);
        
        // if api need server username and password
        if (request.username.length > 0) {
            [_requestManager.requestSerializer setAuthorizationHeaderFieldWithUsername:request.username
                                                                              password:request.password];
        }
        
        // if api need add custom value to HTTPHeaderField
        NSDictionary *headerFieldValueDic = request.customHeaderValue;
        for (NSString *httpHeaderField in headerFieldValueDic.allKeys) {
            NSString *value = headerFieldValueDic[httpHeaderField];
            if ([httpHeaderField isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
                [_requestManager.requestSerializer setValue:value forHTTPHeaderField:httpHeaderField];
            }
            else {
                if (NULL != error) {
                    *error = [NSError errorWithDomain:NSStringFromClass(request.class)
                                                 code:-1
                                             userInfo:@{NSLocalizedFailureReasonErrorKey: @"HTTP HEAD Error",
                                                        NSLocalizedDescriptionKey: @"class of key/value in headerFieldValueDictionary should be NSString."}];
                }
                
                return NO;
            }
        }
        
        AFHTTPRequestOperation *operation = nil;
        
        // if api build custom url request
        NSURLRequest *customUrlRequest = request.customUrlRequest;
        
        if (nil != customUrlRequest) {
            operation = [[AFHTTPRequestOperation alloc] initWithRequest:customUrlRequest];
            [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                [self handleRequestResult:request success:YES error:nil];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                [self handleRequestResult:request success:NO error:error];
            }];
            [_requestManager.operationQueue addOperation:operation];
        }
        else {
            operation = [self requestOperationFor:request];
        }
        
        BOOL success = nil != operation;
        if (success) {
            
            request.requestOperation = operation;
            request.state = kTCHTTPRequestStateExecuting;
            // add to pool
            [self addObserver:request.observer forRequest:request];
        }
        else {
            if (NULL != error) {
                *error = [NSError errorWithDomain:NSStringFromClass(request.class)
                                             code:-1
                                         userInfo:@{NSLocalizedFailureReasonErrorKey: @"Fire Request error",
                                                    NSLocalizedDescriptionKey: @"generate AFHTTPRequestOperation instances failed."}];
            }
        }
        
        return success;
    }
}


- (AFHTTPRequestOperation *)requestOperationFor:(TCHTTPRequest *)request
{
    NSString *url = [self buildRequestUrlForRequest:request];
    NSParameterAssert(url);
    
    NSDictionary *param = request.parameters;
    if ([self.urlFilter respondsToSelector:@selector(filteredParamForParam:)]) {
        param = [self.urlFilter filteredParamForParam:param];
    }
    
    
    void (^successBlock)() = ^{
        [self handleRequestResult:request success:YES error:nil];
    };
    void (^failureBlock)() = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleRequestResult:request success:NO error:error];
    };
    
    AFHTTPRequestOperation *operation = nil;
    
    switch (request.requestMethod) {
            
        case kTCHTTPRequestMethodDownload: {
            NSParameterAssert(request.downloadTargetPath);
            NSString *downloadUrl = [TCHTTPRequestHelper urlString:url appendParameters:param];
            NSParameterAssert(downloadUrl);
            
            if (nil != downloadUrl && request.downloadTargetPath.length > 0) {
                NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:downloadUrl] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:_requestManager.requestSerializer.timeoutInterval];
                operation = [[AFDownloadRequestOperation alloc] initWithRequest:urlRequest
                                                                 fileIdentifier:request.downloadIdentifier
                                                                     targetPath:request.downloadTargetPath
                                                                   shouldResume:request.shouldResumeDownload];
                
                [(AFDownloadRequestOperation *)operation setProgressiveDownloadProgressBlock:request.downloadProgressBlock];
                [(AFDownloadRequestOperation *)operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
                [_requestManager.operationQueue addOperation:operation];
                
                request.downloadProgressBlock = nil;
            }
            break;
        }
            
        case kTCHTTPRequestMethodGet: {
            operation = [_requestManager GET:url parameters:param success:successBlock failure:failureBlock];
            
            break;
        }
            
        case kTCHTTPRequestMethodPost: {
            
            if (nil != request.constructingBodyBlock) {
                operation = [_requestManager POST:url parameters:param constructingBodyWithBlock:request.constructingBodyBlock success:successBlock failure:failureBlock];
                request.constructingBodyBlock = nil;
            }
            else {
                operation = [_requestManager POST:url parameters:param success:successBlock failure:failureBlock];
            }
            break;
        }
            
        case kTCHTTPRequestMethodHead: {
            operation = [_requestManager HEAD:url parameters:param success:successBlock failure:failureBlock];
            
            break;
        }
            
        case kTCHTTPRequestMethodPut: {
            operation = [_requestManager PUT:url parameters:param success:successBlock failure:failureBlock];
            
            break;
        }
            
        case kTCHTTPRequestMethodDelete: {
            operation = [_requestManager DELETE:url parameters:param success:successBlock failure:failureBlock];
            break;
        }
            
        case kTCHTTPRequestMethodPatch: {
            operation = [_requestManager PATCH:url parameters:param success:successBlock failure:failureBlock];
            break;
        }
            
        default:
            break;
    }
    
    return operation;
}


#pragma mark -

- (void)addObserver:(__unsafe_unretained id)observer forRequest:(id<TCHTTPRequestProtocol>)request
{
    if (request.isRetainByRequestPool) {
        return;
    }
    
    NSUInteger key = (NSUInteger)observer;
    
    @synchronized(_requestPool) {
        NSParameterAssert(request);
        
        
        NSMutableDictionary *dic = _requestPool[@(key)];
        if (nil == dic) {
            dic = [NSMutableDictionary dictionary];
            _requestPool[@(key)] = dic;
        }
        
        TCHTTPRequest *preRequest = dic[request.requestIdentifier];
        if (nil != preRequest && preRequest.isRetainByRequestPool) {
            preRequest.isRetainByRequestPool = NO;
            [preRequest cancel];
        }
        
        request.isRetainByRequestPool = YES;
        dic[request.requestIdentifier] = request;
    }
}


- (void)removeForObserver:(void *)observer forIdentifier:(id<NSCopying>)identifier
{
    NSUInteger key = (NSUInteger)observer;
    @synchronized(_requestPool) {
        
        NSMutableDictionary *dic = _requestPool[@(key)];
        
        if (nil != identifier) {
            TCHTTPRequest *request = dic[identifier];
            if (nil != request && request.isRetainByRequestPool) {
                request.isRetainByRequestPool = NO;
                [request cancel];
                [dic removeObjectForKey:identifier];
                if (dic.count < 1) {
                    [_requestPool removeObjectForKey:@(key)];
                }
            }
        }
        else {
            [dic setValue:@NO forKey:@"isRetainByRequestPool"];
            [dic.allValues makeObjectsPerformSelector:@selector(cancel)];
            [_requestPool removeObjectForKey:@(key)];
        }
    }
}


- (void)removeRequestObserver:(__unsafe_unretained id)observer forIdentifier:(id<NSCopying>)identifier;
{
    [self removeForObserver:(__bridge void *)(observer) forIdentifier:identifier];
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
    
    if ([queryUrl hasPrefix:@"http"]) {
        return queryUrl;
    }
    
    NSString *baseUrl = nil;
    
    if (request.shouldUseCDN) {
        if (request.cdnUrl.length > 0) {
            baseUrl = request.cdnUrl;
        }
        else {
            baseUrl = self.cdnURL ? self.cdnURL.absoluteString : self.baseURL.absoluteString;
        }
    }
    else {
        if (request.baseUrl.length > 0) {
            baseUrl = request.baseUrl;
        }
        else {
            baseUrl = self.baseURL.absoluteString;
        }
    }
    
    return [baseUrl stringByAppendingPathComponent:queryUrl];
}

- (void)handleRequestResult:(id<TCHTTPRequestProtocol>)request success:(BOOL)success error:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        request.state = kTCHTTPRequestStateFinished;
        
        // remove from pool
        if (request.isRetainByRequestPool) {
            [self removeForObserver:request.observer forIdentifier:request.requestIdentifier];
        }
        
        BOOL isValid = success;
        if (isValid) {
            
            if (nil != request.responseValidater && [request.responseValidater respondsToSelector:@selector(validateHTTPResponse:)]) {
                isValid = [request.responseValidater validateHTTPResponse:request.responseObject];
            }
            
            if (isValid) {
                [request requestRespondSuccess];
            }
        }
        
        if (nil != request.delegate && [request.delegate respondsToSelector:@selector(processRequest:success:)]) {
            [request.delegate processRequest:request success:isValid];
        }
        
        if (nil != request.resultBlock) {
            request.resultBlock(request, isValid);
            request.resultBlock = nil;
        }
    });
}


#pragma mark - Making HTTP Requests

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

- (TCHTTPRequest *)requestForDownload:(NSString *)url to:(NSString *)dstPath
{
    NSParameterAssert(url);
    NSParameterAssert(dstPath);
    
    TCHTTPRequest *request = [self requestWithMethod:kTCHTTPRequestMethodDownload apiUrl:url host:nil];
    request.downloadTargetPath = dstPath;
    
    return request;
}


@end
