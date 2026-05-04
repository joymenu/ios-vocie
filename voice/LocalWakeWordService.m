//
//  LocalWakeWordService.m
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import "LocalWakeWordService.h"

#import <AVFoundation/AVFoundation.h>

@interface LocalWakeWordService ()

@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, assign, getter=isListening) BOOL listening;
@property (nonatomic, assign) BOOL wakeDetected;

@end

@implementation LocalWakeWordService

- (instancetype)initWithDetector:(id<LocalWakeWordDetecting>)detector {
    self = [super init];
    if (self) {
        _detector = detector;
        _audioEngine = [[AVAudioEngine alloc] init];
    }
    return self;
}

- (void)requestMicrophonePermissionWithCompletion:(void (^)(BOOL granted, NSString *_Nullable message))completion {
    void (^finish)(BOOL) = ^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(granted, granted ? nil : @"麦克风权限未开启，请在系统设置中允许访问。");
        });
    };

    if (@available(iOS 17.0, *)) {
        [AVAudioApplication requestRecordPermissionWithCompletionHandler:finish];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[AVAudioSession sharedInstance] requestRecordPermission:finish];
#pragma clang diagnostic pop
    }
}

- (void)startListening {
    if (self.isListening) {
        return;
    }

    self.wakeDetected = NO;
    [self.detector reset];

    NSError *sessionError = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord
                         mode:AVAudioSessionModeMeasurement
                      options:AVAudioSessionCategoryOptionDuckOthers
                        error:&sessionError];
    if (sessionError) {
        [self notifyFailure:sessionError.localizedDescription];
        return;
    }

    [audioSession setPreferredSampleRate:16000 error:nil];
    [audioSession setPreferredIOBufferDuration:0.08 error:nil];
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&sessionError];
    if (sessionError) {
        [self notifyFailure:sessionError.localizedDescription];
        return;
    }

    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
    AVAudioFormat *format = [inputNode outputFormatForBus:0];
    if (format.sampleRate <= 0 || format.channelCount == 0) {
        [self notifyFailure:@"无法读取麦克风输入格式。"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [inputNode removeTapOnBus:0];
    [inputNode installTapOnBus:0 bufferSize:2048 format:format block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        (void)when;
        [weakSelf processAudioBuffer:buffer sampleRate:format.sampleRate];
    }];

    [self.audioEngine prepare];
    NSError *engineError = nil;
    [self.audioEngine startAndReturnError:&engineError];
    if (engineError) {
        [self notifyFailure:engineError.localizedDescription];
        return;
    }

    self.listening = YES;
    [self notifyOnMain:^{
        [self.delegate localWakeWordServiceDidStartListening];
    }];
}

- (void)stopListening {
    BOOL wasListening = self.isListening;
    self.wakeDetected = NO;
    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
        [self.audioEngine.inputNode removeTapOnBus:0];
    }
    self.listening = NO;
    [self.detector reset];

    if (wasListening) {
        [self notifyOnMain:^{
            [self.delegate localWakeWordServiceDidStopListening];
        }];
    }
}

- (void)processAudioBuffer:(AVAudioPCMBuffer *)buffer sampleRate:(double)sampleRate {
    if (self.wakeDetected || !buffer.floatChannelData || buffer.frameLength == 0) {
        return;
    }

    float *channelData = buffer.floatChannelData[0];
    NSUInteger count = buffer.frameLength;
    NSMutableData *pcmData = [NSMutableData dataWithLength:count * sizeof(int16_t)];
    int16_t *samples = pcmData.mutableBytes;

    for (NSUInteger index = 0; index < count; index++) {
        float clampedSample = MAX(-1.0f, MIN(1.0f, channelData[index]));
        samples[index] = (int16_t)lrintf(clampedSample * INT16_MAX);
    }

    NSString *reason = [self.detector processPCMInt16Samples:samples count:count sampleRate:sampleRate];
    if (reason.length == 0) {
        return;
    }

    self.wakeDetected = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self stopListening];
        [self.delegate localWakeWordServiceDidDetectWakeWordWithReason:reason];
    });
}

- (void)notifyFailure:(NSString *)message {
    [self notifyOnMain:^{
        [self.delegate localWakeWordServiceDidFailWithMessage:message];
    }];
}

- (void)notifyOnMain:(dispatch_block_t)block {
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@end

@interface DevelopmentWakeWordDetector ()

@property (nonatomic, assign) NSUInteger loudFrameCount;
@property (nonatomic, assign) NSUInteger speechFrameCount;
@property (nonatomic, assign) NSUInteger quietFrameCountAfterFirstBurst;
@property (nonatomic, assign) NSUInteger burstCount;
@property (nonatomic, assign) NSTimeInterval lastTriggerTime;

@end

@implementation DevelopmentWakeWordDetector

- (nullable NSString *)processPCMInt16Samples:(const int16_t *)samples count:(NSUInteger)count sampleRate:(double)sampleRate {
    if (count == 0 || sampleRate <= 0) {
        return nil;
    }

    double sumSquares = 0;
    for (NSUInteger index = 0; index < count; index++) {
        double normalizedSample = samples[index] / (double)INT16_MAX;
        sumSquares += normalizedSample * normalizedSample;
    }

    double rms = sqrt(sumSquares / count);
    BOOL isSpeechLike = rms > 0.018;
    BOOL isQuiet = rms < 0.010;

    if (isSpeechLike) {
        self.loudFrameCount += 1;
        self.speechFrameCount += 1;
        self.quietFrameCountAfterFirstBurst = 0;
        if (self.loudFrameCount >= 3) {
            self.burstCount += 1;
            self.loudFrameCount = 0;
        }
    } else {
        self.loudFrameCount = 0;
        if (isQuiet && self.burstCount > 0) {
            self.quietFrameCountAfterFirstBurst += 1;
        }
    }

    if (self.quietFrameCountAfterFirstBurst > 10) {
        [self reset];
        return nil;
    }

    if (self.burstCount >= 2 || self.speechFrameCount >= 4) {
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        if (now - self.lastTriggerTime < 2.5) {
            [self reset];
            return nil;
        }
        self.lastTriggerTime = now;
        [self reset];
        return @"本地开发唤醒 detector 检测到语音唤醒。接入正式 KWS 模型后这里会返回“小星小星”或兼容词“小心小心”。";
    }

    return nil;
}

- (void)reset {
    self.loudFrameCount = 0;
    self.speechFrameCount = 0;
    self.quietFrameCountAfterFirstBurst = 0;
    self.burstCount = 0;
}

@end
