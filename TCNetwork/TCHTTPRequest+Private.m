//
//  TCHTTPRequest+Private.m
//  SudiyiClient
//
//  Created by cdk on 15/11/13.
//  Copyright © 2015年 Sudiyi. All rights reserved.
//

#import "TCHTTPRequest+Private.h"


static NSString *const kNSURLSessionResumeInfoTempFileName = @"NSURLSessionResumeInfoTempFileName";
static NSString *const kNSURLSessionResumeInfoLocalPath = @"NSURLSessionResumeInfoLocalPath";

@implementation TCHTTPRequest (Private)

@dynamic requestTask;
@dynamic uploadProgress;
@dynamic downloadProgress;

- (NSString *)resumeCachePath
{
    return [self.downloadResumeCacheDirectory stringByAppendingPathComponent:self.downloadIdentifier];
}

- (BOOL)isTmpResumeCache
{
    return [self.downloadResumeCacheDirectory hasPrefix:NSTemporaryDirectory()];
}

- (NSString *)resumeInfoTempFileNameFor:(NSData *)data
{
    if (nil == data) {
        return nil;
    }
    
    NSDictionary *dic = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
    NSString *fileName = nil;
    if (nil != dic) {
        fileName = dic[kNSURLSessionResumeInfoTempFileName];
        if (nil == fileName) {
            fileName = [dic[kNSURLSessionResumeInfoLocalPath] lastPathComponent];
        }
        
        if (nil != fileName) {
            fileName = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
        }
    }
    
    return fileName;
}

- (void)loadResumeData:(void(^)(NSData *data))finish
{
    if (nil == finish) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        @autoreleasepool {
            NSData *data = [NSData dataWithContentsOfFile:self.resumeCachePath];
            NSString *tmpDownloadFile = [self resumeInfoTempFileNameFor:data];
            if (nil != tmpDownloadFile) {
                if (!self.isTmpResumeCache) {
                    NSError *error = nil;
                    [[NSFileManager defaultManager] removeItemAtPath:tmpDownloadFile error:NULL];
                    [[NSFileManager defaultManager] copyItemAtPath:[self.downloadResumeCacheDirectory stringByAppendingPathComponent:tmpDownloadFile.lastPathComponent] toPath:tmpDownloadFile error:&error];
                    NSAssert(nil == error, @"%@", error);
                }
                
                if (![[NSFileManager defaultManager] fileExistsAtPath:tmpDownloadFile]) {
                    data = nil;
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                finish(data);
            });
        }
    });
}

- (void)saveResumeData:(NSData *)data finish:(void(^)(BOOL success))finish
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @autoreleasepool {
            BOOL ret = [data writeToFile:self.resumeCachePath atomically:YES];
            
            if (ret && !self.isTmpResumeCache) {
                NSString *tmpDownloadFile = [self resumeInfoTempFileNameFor:data];
                if (nil != tmpDownloadFile) {
                    NSError *error = nil;
                    NSString *cachePath = [self.downloadResumeCacheDirectory stringByAppendingPathComponent:tmpDownloadFile.lastPathComponent];
                    [[NSFileManager defaultManager] removeItemAtPath:cachePath error:NULL];
                    [[NSFileManager defaultManager] moveItemAtPath:tmpDownloadFile toPath:cachePath error:&error];
                    NSAssert(nil == error, @"%@", error);
                }
            }
            
            if (nil != finish) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    finish(ret);
                });
            }
        }
    });
}

- (void)clearCachedResumeData
{
    NSString *path = self.resumeCachePath;
    
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        return;
    }
    
    NSString *cachePath = self.downloadResumeCacheDirectory;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @autoreleasepool {
            // rm tmp files
            NSData *data = [NSData dataWithContentsOfFile:path];
            NSString *tmpDownloadFile = [self resumeInfoTempFileNameFor:data];
            if (nil != tmpDownloadFile) {
                [NSFileManager.defaultManager removeItemAtPath:tmpDownloadFile error:NULL];
                
                if (nil != cachePath) {
                    [NSFileManager.defaultManager removeItemAtPath:[cachePath stringByAppendingPathComponent:tmpDownloadFile.lastPathComponent] error:NULL];
                }
            }
            
            [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
        }
    });
}

@end
