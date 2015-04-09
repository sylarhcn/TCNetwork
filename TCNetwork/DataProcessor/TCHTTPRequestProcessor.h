//
//  TCHTTPRequestProcessor.h
//  TCKit
//
//  Created by dake on 15/3/19.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import "TCHTTPRequestCenterProtocol.h"

#define SYNTHESIZE_TC_SERVICE_DELEGATE(classname) \
\
@protocol classname##Delegate <NSObject> \
\
@optional \
+ (void)classname##Success:(id)info; \
+ (void)classname##Failed:(id)info error:(NSError *)error; \
\
- (void)classname##Success:(id)info; \
- (void)classname##Failed:(id)info error:(NSError *)error; \
\
@end

@interface TCHTTPRequestProcessor : NSObject <TCHTTPRequestDelegate>

@property(nonatomic,assign) SEL successSelector;
@property(nonatomic,assign) SEL failureSelector;

@end
