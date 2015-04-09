//
//  TCBaseParser.h
//  TCKit
//
//  Created by ChenQi on 13-3-27.
//  Copyright (c) 2013年 Dake. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCHTTPResponseValidator.h"

@interface TCBaseParser : NSObject <TCHTTPResponseValidator>

@property(nonatomic,strong) id data;
@property(nonatomic,assign) BOOL success;
@property(nonatomic,strong) NSError *error;


@end

