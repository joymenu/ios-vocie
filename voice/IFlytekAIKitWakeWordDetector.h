//
//  IFlytekAIKitWakeWordDetector.h
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import <Foundation/Foundation.h>

#import "LocalWakeWordService.h"

NS_ASSUME_NONNULL_BEGIN

@interface IFlytekAIKitWakeWordDetector : NSObject <LocalWakeWordDetecting>

@property (nonatomic, copy, readonly) NSString *statusMessage;

+ (nullable instancetype)detectorIfReady;
+ (NSString *)integrationStatusMessage;

@end

NS_ASSUME_NONNULL_END
