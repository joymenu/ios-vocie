//
//  AlarmIntentParser.m
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import "AlarmIntentParser.h"

@implementation AlarmIntentResult
@end

@interface AlarmIntentParser ()

@property (nonatomic, copy, nullable) NSString *pendingOriginalText;

@end

@implementation AlarmIntentParser

- (AlarmIntentResult *)handleUserText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    AlarmIntentResult *result = [[AlarmIntentResult alloc] init];

    if (trimmedText.length == 0) {
        result.assistantText = @"我在，请说出你想设置的闹钟。";
        return result;
    }

    BOOL isAlarmIntent = [trimmedText containsString:@"闹钟"] || self.pendingOriginalText.length > 0;
    if (!isAlarmIntent) {
        result.assistantText = @"我目前可以先帮你设置闹钟。";
        return result;
    }

    NSString *combinedText = self.pendingOriginalText.length > 0
        ? [NSString stringWithFormat:@"%@ %@", self.pendingOriginalText, trimmedText]
        : trimmedText;

    NSString *time = [self parseTimeFromText:combinedText];
    if (time.length == 0) {
        self.pendingOriginalText = combinedText;
        result.assistantText = @"好的，请问闹钟设置在什么时间？";
        return result;
    }

    NSString *date = [self parseDateFromText:combinedText];
    NSString *repeat = [combinedText containsString:@"每天"] ? @"daily" : @"none";
    NSDictionary *payload = @{
        @"intent": @"set_alarm",
        @"status": @"ready",
        @"originalText": combinedText,
        @"slots": @{
            @"date": date,
            @"time": time,
            @"repeat": repeat,
            @"label": [NSNull null]
        }
    };

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&jsonError];
    if (!jsonData || jsonError) {
        result.assistantText = @"闹钟信息已识别，但生成 JSON 时失败了。";
        return result;
    }

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    self.pendingOriginalText = nil;
    result.ready = YES;
    result.jsonString = jsonString;
    result.assistantText = [NSString stringWithFormat:@"已解析为 JSON，后续可调用服务端接口：\n%@", jsonString];
    [self submitParsedAlarmJSON:jsonString];
    return result;
}

- (NSString *)parseDateFromText:(NSString *)text {
    NSInteger dayOffset = 0;
    if ([text containsString:@"后天"]) {
        dayOffset = 2;
    } else if ([text containsString:@"明天"]) {
        dayOffset = 1;
    } else if ([text containsString:@"今天"]) {
        dayOffset = 0;
    }

    NSDate *date = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitDay
                                                            value:dayOffset
                                                           toDate:[NSDate date]
                                                          options:0];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd";
    return [formatter stringFromDate:date];
}

- (NSString *)parseTimeFromText:(NSString *)text {
    NSString *normalizedText = [self normalizeChineseNumbersInText:text];
    NSInteger hour = NSNotFound;
    NSInteger minute = 0;

    NSRegularExpression *colonExpression = [NSRegularExpression regularExpressionWithPattern:@"([0-2]?\\d)\\s*[:：]\\s*([0-5]?\\d)"
                                                                                    options:0
                                                                                      error:nil];
    NSTextCheckingResult *colonMatch = [colonExpression firstMatchInString:normalizedText
                                                                   options:0
                                                                     range:NSMakeRange(0, normalizedText.length)];
    if (colonMatch) {
        hour = [[normalizedText substringWithRange:[colonMatch rangeAtIndex:1]] integerValue];
        minute = [[normalizedText substringWithRange:[colonMatch rangeAtIndex:2]] integerValue];
    } else {
        NSRegularExpression *pointExpression = [NSRegularExpression regularExpressionWithPattern:@"([0-2]?\\d)\\s*点\\s*([0-5]?\\d)?\\s*分?"
                                                                                        options:0
                                                                                          error:nil];
        NSTextCheckingResult *pointMatch = [pointExpression firstMatchInString:normalizedText
                                                                       options:0
                                                                         range:NSMakeRange(0, normalizedText.length)];
        if (pointMatch) {
            hour = [[normalizedText substringWithRange:[pointMatch rangeAtIndex:1]] integerValue];
            if ([pointMatch rangeAtIndex:2].location != NSNotFound) {
                minute = [[normalizedText substringWithRange:[pointMatch rangeAtIndex:2]] integerValue];
            }
            if ([normalizedText containsString:@"半"]) {
                minute = 30;
            }
        }
    }

    if (hour == NSNotFound || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return nil;
    }

    if ([self text:normalizedText containsAny:@[@"下午", @"晚上", @"今晚", @"傍晚"]] && hour < 12) {
        hour += 12;
    }

    if ([self text:normalizedText containsAny:@[@"中午"]] && hour < 11) {
        hour += 12;
    }

    if ([self text:normalizedText containsAny:@[@"凌晨"]] && hour == 12) {
        hour = 0;
    }

    return [NSString stringWithFormat:@"%02ld:%02ld", (long)hour, (long)minute];
}

- (NSString *)normalizeChineseNumbersInText:(NSString *)text {
    NSMutableString *normalized = [text mutableCopy];
    NSDictionary<NSString *, NSString *> *numbers = @{
        @"二十四": @"24",
        @"二十三": @"23",
        @"二十二": @"22",
        @"二十一": @"21",
        @"二十": @"20",
        @"十九": @"19",
        @"十八": @"18",
        @"十七": @"17",
        @"十六": @"16",
        @"十五": @"15",
        @"十四": @"14",
        @"十三": @"13",
        @"十二": @"12",
        @"十一": @"11",
        @"十": @"10",
        @"九": @"9",
        @"八": @"8",
        @"七": @"7",
        @"六": @"6",
        @"五": @"5",
        @"四": @"4",
        @"三": @"3",
        @"两": @"2",
        @"二": @"2",
        @"一": @"1",
        @"零": @"0",
        @"〇": @"0"
    };

    NSArray<NSString *> *keys = [numbers.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
        if (left.length > right.length) {
            return NSOrderedAscending;
        }
        if (left.length < right.length) {
            return NSOrderedDescending;
        }
        return [left compare:right];
    }];

    for (NSString *key in keys) {
        [normalized replaceOccurrencesOfString:key
                                    withString:numbers[key]
                                       options:0
                                         range:NSMakeRange(0, normalized.length)];
    }
    return normalized;
}

- (BOOL)text:(NSString *)text containsAny:(NSArray<NSString *> *)tokens {
    for (NSString *token in tokens) {
        if ([text containsString:token]) {
            return YES;
        }
    }
    return NO;
}

- (void)submitParsedAlarmJSON:(NSString *)jsonString {
    NSLog(@"TODO submit alarm JSON to server: %@", jsonString);
}

@end
