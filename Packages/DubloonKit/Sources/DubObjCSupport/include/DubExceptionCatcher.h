//
//  DubExceptionCatcher.h
//  DubloonKit
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs a block and hands back any Objective-C exception it raised, instead of letting it end
/// the process.
///
/// Swift cannot catch `NSException`. AVAudioEngine raises one for a graph it will not build
/// (`connect:to:format:` with a format the mixer cannot take) and for a player node started
/// before its first render cycle, and each of those was a crash the app could do nothing about.
/// Behind this, they are errors.
@interface DubExceptionCatcher : NSObject

/// The exception `block` raised, as an error in the `DubObjCExceptionDomain` domain with the
/// exception's name and reason in its user info, or nil when the block returned normally.
+ (nullable NSError *)catchExceptionIn:(void (NS_NOESCAPE ^)(void))block;

@end

/// The domain of the errors `DubExceptionCatcher` returns. Code is always 1.
FOUNDATION_EXPORT NSErrorDomain const DubObjCExceptionDomain;
/// User-info key holding the exception's name.
FOUNDATION_EXPORT NSErrorUserInfoKey const DubObjCExceptionNameKey;

NS_ASSUME_NONNULL_END
