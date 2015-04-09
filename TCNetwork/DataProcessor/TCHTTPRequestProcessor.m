//
//  TCHTTPRequestProcessor.m
//  TCKit
//
//  Created by dake on 15/3/19.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import "TCHTTPRequestProcessor.h"

@implementation TCHTTPRequestProcessor

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSString *className = NSStringFromClass(self.class);
        _successSelector = NSSelectorFromString([className stringByAppendingString:@"Success:"]);
        _failureSelector = NSSelectorFromString([className stringByAppendingString:@"Failed:error:"]);
    }
    return self;
}


+ (void)processRequest:(TCHTTPRequest *)request success:(BOOL)success
{
  
}

- (void)processRequest:(TCHTTPRequest *)request success:(BOOL)success
{

}


@end
