//
//  SpeechRecognitionService.m
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import "SpeechRecognitionService.h"

#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>

@interface SpeechRecognitionService ()

@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong, nullable) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (nonatomic, strong, nullable) SFSpeechRecognitionTask *recognitionTask;
@property (nonatomic, assign, getter=isListening) BOOL listening;
@property (nonatomic, assign) BOOL shouldKeepListening;
@property (nonatomic, assign) BOOL isRestarting;
@property (nonatomic, assign) NSUInteger sessionGeneration;

@end

@implementation SpeechRecognitionService

- (instancetype)init {
    self = [super init];
    if (self) {
        _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"zh_CN"]];
        _audioEngine = [[AVAudioEngine alloc] init];
        _reportsPartialResults = YES;
        _maximumSessionDuration = 0;
        _restartDelay = 0.35;
    }
    return self;
}

- (void)requestAuthorizationWithCompletion:(void (^)(BOOL granted, NSString *_Nullable message))completion {
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        if (status != SFSpeechRecognizerAuthorizationStatusAuthorized) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @"语音识别权限未开启，请在系统设置中允许访问。");
            });
            return;
        }

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
    }];
}

- (void)startListening {
    self.shouldKeepListening = YES;
    if (self.isListening || self.isRestarting) {
        return;
    }
    [self startCurrentRecognitionSession];
}

- (void)stopListening {
    self.shouldKeepListening = NO;
    self.isRestarting = NO;
    self.sessionGeneration += 1;
    [self stopCurrentRecognitionSessionAndNotify:YES];
}

- (void)startCurrentRecognitionSession {
    if (self.isListening) {
        return;
    }

    if (!self.speechRecognizer.isAvailable) {
        [self.delegate speechServiceDidFailWithMessage:@"当前语音识别服务不可用。"];
        return;
    }

    [self.recognitionTask cancel];
    self.recognitionTask = nil;

    NSError *sessionError = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord
                         mode:AVAudioSessionModeMeasurement
                      options:AVAudioSessionCategoryOptionDuckOthers
                        error:&sessionError];
    if (sessionError) {
        [self.delegate speechServiceDidFailWithMessage:sessionError.localizedDescription];
        return;
    }

    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&sessionError];
    if (sessionError) {
        [self.delegate speechServiceDidFailWithMessage:sessionError.localizedDescription];
        return;
    }

    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    self.recognitionRequest.shouldReportPartialResults = self.reportsPartialResults;
    NSUInteger currentGeneration = self.sessionGeneration + 1;
    self.sessionGeneration = currentGeneration;

    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    if (recordingFormat.sampleRate <= 0) {
        [self.delegate speechServiceDidFailWithMessage:@"无法读取麦克风输入格式。"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest
                                                               resultHandler:^(SFSpeechRecognitionResult *_Nullable result, NSError *_Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        if (result.bestTranscription.formattedString.length > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate speechServiceDidRecognizeText:result.bestTranscription.formattedString
                                                     isFinal:result.isFinal];
            });
        }

        if (error || result.isFinal) {
            BOOL shouldRestart = self.shouldKeepListening;
            [self stopCurrentRecognitionSessionAndNotify:YES];
            if (shouldRestart) {
                [self restartAfterDelay];
            }
        }
    }];

    [inputNode removeTapOnBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        [weakSelf.recognitionRequest appendAudioPCMBuffer:buffer];
        (void)when;
    }];

    [self.audioEngine prepare];
    NSError *engineError = nil;
    [self.audioEngine startAndReturnError:&engineError];
    if (engineError) {
        [self.delegate speechServiceDidFailWithMessage:engineError.localizedDescription];
        [self stopCurrentRecognitionSessionAndNotify:YES];
        return;
    }

    self.listening = YES;
    [self notifyOnMain:^{
        [self.delegate speechServiceDidStartListening];
    }];
    [self scheduleSessionLimitForGeneration:currentGeneration];
}

- (void)stopCurrentRecognitionSessionAndNotify:(BOOL)notify {
    BOOL wasListening = self.isListening;

    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
        [self.audioEngine.inputNode removeTapOnBus:0];
    }

    [self.recognitionRequest endAudio];
    [self.recognitionTask cancel];
    self.recognitionRequest = nil;
    self.recognitionTask = nil;
    self.listening = NO;

    if (notify && wasListening) {
        [self notifyOnMain:^{
            [self.delegate speechServiceDidStopListening];
        }];
    }
}

- (void)notifyOnMain:(dispatch_block_t)block {
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)restartAfterDelay {
    if (self.isRestarting) {
        return;
    }

    self.isRestarting = YES;
    NSTimeInterval delay = MAX(0.1, self.restartDelay);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.isRestarting = NO;
        if (self.shouldKeepListening && !self.isListening) {
            [self startCurrentRecognitionSession];
        }
    });
}

- (void)scheduleSessionLimitForGeneration:(NSUInteger)generation {
    if (self.maximumSessionDuration <= 0) {
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.maximumSessionDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation != self.sessionGeneration || !self.shouldKeepListening || !self.isListening) {
            return;
        }

        [self stopCurrentRecognitionSessionAndNotify:YES];
        if (self.shouldKeepListening) {
            [self restartAfterDelay];
        }
    });
}

@end
