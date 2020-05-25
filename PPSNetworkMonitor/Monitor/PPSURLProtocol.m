//
//  PPSURLProtocol.m
//  PPSNetworkMonitor
//
//  Created by ppsheep on 2017/4/8.
//  Copyright © 2017年 ppsheep. All rights reserved.
//

#import "PPSURLProtocol.h"
#import "PPSURLSessionConfiguration.h"

static NSString *const PPSHTTP = @"PPSHTTP";//为了避免canInitWithRequest和canonicalRequestForRequest的死循环

@interface PPSURLProtocol()<NSURLConnectionDelegate,NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLSessionDataTask *task;


@property (nonatomic, strong) NSURLRequest *pps_request;
@property (nonatomic, strong) NSURLResponse *pps_response;
@property (nonatomic, strong) NSMutableData *pps_data;


@end

@implementation PPSURLProtocol

#pragma mark - init
- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

+ (void)load {
    
}

+ (void)start {
    PPSURLSessionConfiguration *sessionConfiguration = [PPSURLSessionConfiguration defaultConfiguration];
    [NSURLProtocol registerClass:[PPSURLProtocol class]];
    if (![sessionConfiguration isSwizzle]) {
        [sessionConfiguration load];
    }
}

+ (void)end {
    PPSURLSessionConfiguration *sessionConfiguration = [PPSURLSessionConfiguration defaultConfiguration];
    [NSURLProtocol unregisterClass:[PPSURLProtocol class]];
    if ([sessionConfiguration isSwizzle]) {
        [sessionConfiguration unload];
    }
}


/**
 需要控制的请求

 @param request 此次请求
 @return 是否需要监控
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    
    if (![request.URL.scheme isEqualToString:@"http"] &&
        ![request.URL.scheme isEqualToString:@"https"]) {
        return NO;
    }
    //如果是已经拦截过的  就放行
    if ([NSURLProtocol propertyForKey:PPSHTTP inRequest:request] ) {
        return NO;
    }
    return YES;
}

/**
 设置我们自己的自定义请求
 可以在这里统一加上头之类的
 
 @param request 应用的此次请求
 @return 我们自定义的请求
 */
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    [NSURLProtocol setProperty:@YES
                        forKey:PPSHTTP
                     inRequest:mutableReqeust];
    return [mutableReqeust copy];
}

- (void)startLoading {
    NSURLRequest *request = [[self class] canonicalRequestForRequest:self.request];
    
    NSURLSessionDataTask *task =  [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            [self.client URLProtocol:self didFailWithError:error];
        } else {
            
            id json = [self responseJSONFromData:data];
            NSLog(@"json = %@",json);
            
            [self.client URLProtocol:self didLoadData:data];
            [self.client URLProtocolDidFinishLoading:self];
        }
    }];
    
    [task resume];
    self.task = task;
}

- (void)stopLoading {
    [self.task cancel];
    
    NSLog(@"self.request = %@",self.request);
    NSLog(@"self.response = %@",self.cachedResponse);
    
}

//转换json
-(id)responseJSONFromData:(NSData *)data {
    if(data == nil) return nil;
    NSError *error = nil;
    id returnValue = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if(error) {
        NSLog(@"JSON Parsing Error: %@", error);
        //https://github.com/coderyi/NetworkEye/issues/3
        return nil;
    }
    //https://github.com/coderyi/NetworkEye/issues/1
    if (!returnValue || returnValue == [NSNull null]) {
        return nil;
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:returnValue options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

@end
