//
//  TCHTTPRequest.h
//  TCKit
//
//  Created by dake on 15/3/15.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCHTTPResponseValidator.h"
#import "TCHTTPRequestCenterProtocol.h"


typedef NS_ENUM(NSInteger, TCHTTPRequestMethod) {
    kTCHTTPRequestMethodGet = 0,
    kTCHTTPRequestMethodPost,
    kTCHTTPRequestMethodHead,
    kTCHTTPRequestMethodPut,
    kTCHTTPRequestMethodDelete,
    kTCHTTPRequestMethodPatch,
    kTCHTTPRequestMethodDownload,
};

typedef NS_ENUM(NSInteger, TCHTTPRequestSerializerType) {
    kTCHTTPRequestSerializerTypeHTTP = 0,
    kTCHTTPRequestSerializerTypeJSON,
};


@protocol AFMultipartFormData;
typedef void (^AFConstructingBlock)(id<AFMultipartFormData> formData);

@class AFDownloadRequestOperation;
typedef void (^AFDownloadProgressBlock)(AFDownloadRequestOperation *operation, NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile);

@class TCHTTPRequest;
typedef void (^TCRequestResultBlockType)(TCHTTPRequest *request, BOOL successe);


#pragma mark -

@class AFHTTPRequestOperation;
@interface TCHTTPRequest : NSObject <TCHTTPRequestProtocol>

//
// callback
//
@property(nonatomic,weak) id<TCHTTPRequestDelegate> delegate;
@property(nonatomic,copy) TCRequestResultBlockType resultBlock;

@property(nonatomic,strong) id<TCHTTPResponseValidator> responseValidater;
@property(nonatomic,weak) id<TCHTTPRequestCenterProtocol> requestAgent;
@property(nonatomic,strong) AFHTTPRequestOperation *requestOperation;

@property(nonatomic,copy) NSString *requestIdentifier;
@property(nonatomic,strong) NSDictionary *userInfo;
@property(atomic,assign) TCHTTPRequestState state;
@property(nonatomic,assign,readonly) BOOL isCancelled;

//
// construct request
//
@property(nonatomic,copy) NSString *apiUrl; // "getUserInfo/"
@property(nonatomic,copy) NSString *baseUrl; // "http://eet/oo/"
@property(nonatomic,copy) NSString *cdnUrl; // "http://sdfd/oo"

// Auto convert to query string, if requestMethod is GET
@property(nonatomic,strong) NSDictionary *parameters;

@property(nonatomic,assign) BOOL shouldUseCDN;
@property(nonatomic,assign) NSTimeInterval timeoutInterval; // default: 60s
@property(nonatomic,assign) TCHTTPRequestMethod requestMethod;
@property(nonatomic,assign) TCHTTPRequestSerializerType serializerType;


- (instancetype)initWithMethod:(TCHTTPRequestMethod)method;

- (void)setObserver:(__unsafe_unretained id)observer;

/**
 @brief	start a http request with checking available cache,
 if cache is available, no request will be fired.
 
 @param error [OUT] param invalid, etc...
 
 @return <#return value description#>
 */
- (BOOL)start:(NSError **)error;

- (BOOL)startWithResult:(TCRequestResultBlockType)resultBlock error:(NSError **)error;

// delegate, resulteBlock always called, even if request was cancelled.
- (void)cancel;


- (BOOL)isExecuting;

/**
 @brief	request response object
 
 @return [NSDictionary]: json dictionary, [NSString]: download target path
 */
- (id)responseObject;



#pragma mark - Upload

@property(nonatomic,copy) AFConstructingBlock constructingBodyBlock;


#pragma mark - Download

@property(nonatomic,assign) BOOL shouldResumeDownload; // default: NO
@property(nonatomic,copy) NSString *downloadIdentifier; // such as hash string, but can not be file system path!
@property(nonatomic,copy) NSString *downloadTargetPath;
@property(nonatomic,copy) AFDownloadProgressBlock downloadProgressBlock;


#pragma mark - Custom

// custom value in HTTP Head
@property(nonatomic,strong) NSDictionary *customHeaderValue;
// set none nil to ignore requestUrl, argument, requestMethod, serializerType
@property(nonatomic,strong) NSURLRequest *customUrlRequest;

@property(nonatomic,copy,readonly) NSString *username;
@property(nonatomic,copy,readonly) NSString *password;

/**
 Sets the "Authorization" HTTP header set in request objects made by the HTTP client to a basic authentication value with Base64-encoded username and password. This overwrites any existing value for this header.
 
 @param username The HTTP basic auth username
 @param password The HTTP basic auth password
 */
- (void)setAuthorizationHeaderFieldWithUsername:(NSString *)username
                                       password:(NSString *)password;


@end

