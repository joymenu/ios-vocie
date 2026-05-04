//
//  LocalWakeWordService.h
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LocalWakeWordServiceDelegate <NSObject>

- (void)localWakeWordServiceDidStartListening;
- (void)localWakeWordServiceDidStopListening;
- (void)localWakeWordServiceDidDetectWakeWordWithReason:(NSString *)reason;
- (void)localWakeWordServiceDidFailWithMessage:(NSString *)message;

@end

@protocol LocalWakeWordDetecting <NSObject>

- (nullable NSString *)processPCMInt16Samples:(const int16_t *)samples count:(NSUInteger)count sampleRate:(double)sampleRate;
- (void)reset;

@end

@interface LocalWakeWordService : NSObject

@property (nonatomic, weak, nullable) id<LocalWakeWordServiceDelegate> delegate;
@property (nonatomic, strong) id<LocalWakeWordDetecting> detector;
@property (nonatomic, readonly, getter=isListening) BOOL listening;

- (instancetype)initWithDetector:(id<LocalWakeWordDetecting>)detector;
- (void)requestMicrophonePermissionWithCompletion:(void (^)(BOOL granted, NSString *_Nullable message))completion;
- (void)startListening;
- (void)stopListening;

@end

@interface DevelopmentWakeWordDetector : NSObject <LocalWakeWordDetecting>

@end

NS_ASSUME_NONNULL_END
