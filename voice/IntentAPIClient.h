//
//  IntentAPIClient.h
//  voice
//
//  Created by Codex on 2026/5/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IntentAPIResult : NSObject

@property (nonatomic, copy) NSString *displayText;
@property (nonatomic, copy) NSString *spokenText;
@property (nonatomic, copy, nullable) NSString *intent;
@property (nonatomic, copy, nullable) NSString *status;
@property (nonatomic, copy, nullable) NSString *source;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *slots;

@end

typedef void (^IntentAPICompletion)(IntentAPIResult *_Nullable result, NSError *_Nullable error);

@interface IntentAPIClient : NSObject

- (void)parseIntentWithText:(NSString *)text completion:(IntentAPICompletion)completion;

/// Short Chinese summary for UI when `parseIntentWithText` completes with `error` or unusable payload.
+ (NSString *)localizedSummaryForIntentAPIError:(NSError *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
