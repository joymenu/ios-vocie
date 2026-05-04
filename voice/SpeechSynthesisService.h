//
//  SpeechSynthesisService.h
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SpeechSynthesisService : NSObject

@property (nonatomic, readonly, getter=isSpeaking) BOOL speaking;

- (void)speakText:(NSString *)text completion:(void (^_Nullable)(void))completion;
- (void)stopSpeaking;

@end

NS_ASSUME_NONNULL_END
