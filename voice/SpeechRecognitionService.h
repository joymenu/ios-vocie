//
//  SpeechRecognitionService.h
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SpeechRecognitionServiceDelegate <NSObject>

- (void)speechServiceDidStartListening;
- (void)speechServiceDidStopListening;
- (void)speechServiceDidRecognizeText:(NSString *)text isFinal:(BOOL)isFinal;
- (void)speechServiceDidFailWithMessage:(NSString *)message;

@end

@interface SpeechRecognitionService : NSObject

@property (nonatomic, weak, nullable) id<SpeechRecognitionServiceDelegate> delegate;
@property (nonatomic, readonly, getter=isListening) BOOL listening;

- (void)requestAuthorizationWithCompletion:(void (^)(BOOL granted, NSString *_Nullable message))completion;
- (void)startListening;
- (void)stopListening;

@end

NS_ASSUME_NONNULL_END
