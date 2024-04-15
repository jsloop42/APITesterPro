//
//  Utils.h
//  APITesterPro
//
//  Created by jsloop on 07.04.2024.
//  Copyright © 2024 Jaseem V V. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define NSLog(FORMAT, ...) fprintf(stderr, "%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

#ifdef DEBUG
#   define debug(...) NSLog(__VA_ARGS__)
#   define info(...) NSLog(__VA_ARGS__)
#   define error(...) NSLog(__VA_ARGS__)
#else
#   define debug(...) ((void)0)
#   define info(...) NSLog(__VA_ARGS__)
#   define error(...) NSLog(__VA_ARGS__)
#endif

@interface Utils : NSObject

@end

NS_ASSUME_NONNULL_END
