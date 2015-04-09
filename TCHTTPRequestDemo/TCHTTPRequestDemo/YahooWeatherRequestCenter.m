//
//  YahooWeatherRequestCenter.m
//  TCHTTPRequestDemo
//
//  Created by cdk on 15/4/9.
//  Copyright (c) 2015年 dake. All rights reserved.
//

#import "YahooWeatherRequestCenter.h"

static NSString *const kHost = @"http://weather.yahooapis.com/";

@implementation YahooWeatherRequestCenter

+ (instancetype)defaultCenter
{
    static YahooWeatherRequestCenter *s_defaultCenter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_defaultCenter = [[self alloc] initWithBaseURL:[NSURL URLWithString:kHost]];
    });
    
    return s_defaultCenter;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.timeoutInterval = 90.0f;
        // You can set urlFilter delegate here to self, or other.
        // self.urlFilter = self;
    }
    return self;
}


- (TCHTTPRequest *)fetchWeatherForWOEID:(NSString *)woeiID beforeRun:(void(^)(TCHTTPRequest *request))beforeRun
{
    if (nil == woeiID || woeiID.length < 1) {
        return nil;
    }

    TCHTTPRequest *request = [self requestWithMethod:kTCHTTPRequestMethodGet apiUrl:@"forecastrss" host:nil];
    if (nil != beforeRun) {
        beforeRun(request);
    }
    request.parameters = @{@"w": woeiID,
                           @"u": @"c"};
    return [request start:NULL] ? request : nil;
}


@end
