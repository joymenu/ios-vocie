//
//  WakeWordTextMatcher.h
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WakeWordTextMatcher : NSObject

+ (BOOL)isOnlyWakeWordText:(NSString *)text;
+ (NSString *)textByRemovingLeadingWakeWordsFromText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
