//
//  SpeechSynthesisService.m
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import "SpeechSynthesisService.h"

#import <AVFoundation/AVFoundation.h>

@interface SpeechSynthesisService () <AVSpeechSynthesizerDelegate>

@property (nonatomic, strong) AVSpeechSynthesizer *synthesizer;
@property (nonatomic, copy, nullable) void (^completion)(void);

@end

@implementation SpeechSynthesisService

- (instancetype)init {
    self = [super init];
    if (self) {
        _synthesizer = [[AVSpeechSynthesizer alloc] init];
        _synthesizer.delegate = self;
    }
    return self;
}

- (BOOL)isSpeaking {
    return self.synthesizer.isSpeaking;
}

- (void)speakText:(NSString *)text completion:(void (^)(void))completion {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedText.length == 0) {
        if (completion) {
            completion();
        }
        return;
    }

    if (self.synthesizer.isSpeaking) {
        [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    }

    self.completion = completion;

    NSError *sessionError = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback
                         mode:AVAudioSessionModeSpokenAudio
                      options:AVAudioSessionCategoryOptionDuckOthers
                        error:&sessionError];
    if (sessionError) {
        NSLog(@"Failed to configure speech synthesis audio session: %@", sessionError.localizedDescription);
    }

    AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:trimmedText];
    utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
    utterance.rate = 0.48;
    utterance.pitchMultiplier = 1.05;
    [self.synthesizer speakUtterance:utterance];
}

- (void)stopSpeaking {
    self.completion = nil;
    [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    (void)synthesizer;
    (void)utterance;
    [self finishCompletion];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance {
    (void)synthesizer;
    (void)utterance;
    [self finishCompletion];
}

- (void)finishCompletion {
    void (^completion)(void) = self.completion;
    self.completion = nil;
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), completion);
    }
}

@end
