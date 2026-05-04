//
//  IFlytekAIKitWakeWordDetector.m
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import "IFlytekAIKitWakeWordDetector.h"

static NSString *const IFlytekAbilityId = @"e867a88f2";

@interface IFlytekAIKitWakeWordDetector ()

@property (nonatomic, copy) NSString *statusMessage;
@property (nonatomic, strong) NSDictionary<NSString *, id> *config;
@property (nonatomic, assign) BOOL sdkAvailable;

@end

@implementation IFlytekAIKitWakeWordDetector

+ (nullable instancetype)detectorIfReady {
    IFlytekAIKitWakeWordDetector *detector = [[IFlytekAIKitWakeWordDetector alloc] init];
    if (![detector loadAndValidateConfiguration]) {
        return nil;
    }
    if (![detector validateSDKPresence]) {
        return nil;
    }

    // The official AIKit package is distributed from xfyun.cn and includes
    // AIKIT.framework, an ability engine framework, and AEEResource.bundle.
    // Once those binary artifacts are added, replace this soft bridge with
    // the strongly typed AIKit calls from the SDK Demo:
    // 1. [AiHelper initSDK:... ability:@"e867a88f2"]
    // 2. [AiHelper loadData:@"e867a88f2" data:keywordData]
    // 3. [AiHelper specifyDataSet:@"e867a88f2" key:@"key_word" ...]
    // 4. [AiHelper start:@"e867a88f2" param:... ctxContent:...]
    // 5. Stream PCM frames through [AiHelper write:handle:].
    detector.statusMessage = @"讯飞 AIKit SDK 和配置已检测到，但当前演示版仍使用开发唤醒 detector，避免占位实现无法触发唤醒。";
    return nil;
}

+ (NSString *)integrationStatusMessage {
    IFlytekAIKitWakeWordDetector *detector = [[IFlytekAIKitWakeWordDetector alloc] init];
    if (![detector loadAndValidateConfiguration]) {
        return detector.statusMessage;
    }
    if (![detector validateSDKPresence]) {
        return detector.statusMessage;
    }
    return @"讯飞 AIKit 配置和 SDK 已检测到，但强类型唤醒回调尚未接入，当前演示版已使用开发唤醒 detector。";
}

- (nullable NSString *)processPCMInt16Samples:(const int16_t *)samples count:(NSUInteger)count sampleRate:(double)sampleRate {
    (void)samples;
    (void)count;
    (void)sampleRate;
    return nil;
}

- (void)reset {
}

- (BOOL)loadAndValidateConfiguration {
    NSString *configPath = [NSBundle.mainBundle pathForResource:@"IFlytekAIKitConfig" ofType:@"plist"];
    if (configPath.length == 0) {
        self.statusMessage = @"未找到 IFlytekAIKitConfig.plist，已使用开发唤醒 detector。";
        return NO;
    }

    NSDictionary<NSString *, id> *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
    NSString *appId = [self trimmedString:config[@"appId"]];
    NSString *apiKey = [self trimmedString:config[@"apiKey"]];
    NSString *apiSecret = [self trimmedString:config[@"apiSecret"]];
    NSString *abilityId = [self trimmedString:config[@"abilityId"]];

    if (appId.length == 0 || apiKey.length == 0 || apiSecret.length == 0 ||
        [appId containsString:@"REPLACE_"] ||
        [apiKey containsString:@"REPLACE_"] ||
        [apiSecret containsString:@"REPLACE_"]) {
        self.statusMessage = @"讯飞 appId/apiKey/apiSecret 未配置，已使用开发唤醒 detector。";
        return NO;
    }

    if (abilityId.length == 0) {
        NSMutableDictionary *mutableConfig = [config mutableCopy];
        mutableConfig[@"abilityId"] = IFlytekAbilityId;
        config = mutableConfig;
    }

    NSString *keywordPath = [NSBundle.mainBundle pathForResource:@"keyword" ofType:@"txt"];
    if (keywordPath.length == 0) {
        self.statusMessage = @"未找到讯飞唤醒词 keyword.txt，已使用开发唤醒 detector。";
        return NO;
    }

    self.config = config;
    return YES;
}

- (BOOL)validateSDKPresence {
    BOOL hasAiHelperClass = NSClassFromString(@"AiHelper") != nil;
    BOOL hasAIKITBundle = [NSBundle.mainBundle pathForResource:@"AEEResource" ofType:@"bundle"].length > 0 ||
                          [NSBundle.mainBundle pathForResource:@"AIKITResource" ofType:@"bundle"].length > 0;

    if (!hasAiHelperClass) {
        self.statusMessage = @"未检测到讯飞 AIKIT.framework/AiHelper 类，已使用开发唤醒 detector。";
        return NO;
    }

    if (!hasAIKITBundle) {
        self.statusMessage = @"未检测到讯飞 AEEResource.bundle，已使用开发唤醒 detector。";
        return NO;
    }

    self.sdkAvailable = YES;
    return YES;
}

- (NSString *)trimmedString:(id)value {
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

@end
