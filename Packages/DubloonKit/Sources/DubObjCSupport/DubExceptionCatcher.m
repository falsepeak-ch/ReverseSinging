//
//  DubExceptionCatcher.m
//  DubloonKit
//

#import "DubExceptionCatcher.h"

NSErrorDomain const DubObjCExceptionDomain = @"com.falsepeak.dubloon.objc-exception";
NSErrorUserInfoKey const DubObjCExceptionNameKey = @"DubObjCExceptionName";

@implementation DubExceptionCatcher

+ (nullable NSError *)catchExceptionIn:(void (NS_NOESCAPE ^)(void))block {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        NSMutableDictionary<NSErrorUserInfoKey, id> *info = [NSMutableDictionary dictionary];
        info[DubObjCExceptionNameKey] = exception.name;
        info[NSLocalizedDescriptionKey] = exception.reason ?: exception.name;
        return [NSError errorWithDomain:DubObjCExceptionDomain code:1 userInfo:info];
    }
}

@end
