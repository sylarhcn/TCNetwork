//
//  TCHTTPResponseValidator.h
//  TCKit
//
//  Created by dake on 15/3/15.
//  Copyright (c) 2015年 Dake. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TCHTTPResponseValidator <NSObject>

@required
@property(nonatomic,strong) id data;
@property(nonatomic,assign) BOOL success;
@property(nonatomic,strong) NSError *error;

@optional
+ (BOOL)validateHTTPResponse:(id)obj;
- (BOOL)validateHTTPResponse:(id)obj;

@end
