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
        result.assistantText = @"我在，可以帮你设置提醒，也可以查询手表数据。";
        result.spokenText = result.assistantText;
        return result;
    }

    if (self.pendingOriginalText.length == 0 && [self isWatchDataQueryIntent:trimmedText]) {
        return [self handleWatchDataQueryText:trimmedText];
    }

    BOOL isReminderIntent = [self isReminderIntentText:trimmedText] || self.pendingOriginalText.length > 0;
    if (isReminderIntent) {
        return [self handleReminderText:trimmedText];
    }

    result.assistantText = @"我现在可以处理提醒设置和手表数据查询。你可以说“明天早上 8 点提醒我吃药”，也可以说“查一下现在心率”。";
    result.spokenText = @"我现在可以处理提醒设置和手表数据查询。";
    return result;
}

- (AlarmIntentResult *)handleReminderText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    AlarmIntentResult *result = [[AlarmIntentResult alloc] init];
    NSString *combinedText = self.pendingOriginalText.length > 0
        ? [NSString stringWithFormat:@"%@ %@", self.pendingOriginalText, trimmedText]
        : trimmedText;

    NSString *time = [self parseTimeFromText:combinedText];
    if (time.length == 0) {
        self.pendingOriginalText = combinedText;
        result.assistantText = @"好的，请问提醒设置在什么时间？";
        result.spokenText = result.assistantText;
        return result;
    }

    NSString *date = [self parseDateFromText:combinedText];
    NSString *repeat = [self parseRepeatFromText:combinedText];
    NSString *category = [self reminderCategoryFromText:combinedText];
    NSString *title = [self reminderTitleFromText:combinedText category:category];
    NSDictionary *payload = @{
        @"intent": @"create_reminder",
        @"status": @"ready",
        @"category": category,
        @"originalText": combinedText,
        @"slots": @{
            @"date": date,
            @"time": time,
            @"repeat": repeat,
            @"title": title,
            @"medicineName": [category isEqualToString:@"medication"] ? title : (id)[NSNull null],
            @"dosage": [NSNull null]
        }
    };

    NSString *jsonString = [self jsonStringFromPayload:payload];
    if (jsonString.length == 0) {
        result.assistantText = @"提醒信息已识别，但生成 JSON 时失败了。";
        result.spokenText = result.assistantText;
        return result;
    }

    self.pendingOriginalText = nil;
    result.ready = YES;
    result.jsonString = jsonString;
    result.assistantText = [self mockAssistantTextForReminderPayload:payload];
    result.spokenText = result.assistantText;
    [self submitParsedIntentJSON:jsonString];
    return result;
}

- (AlarmIntentResult *)handleWatchDataQueryText:(NSString *)text {
    AlarmIntentResult *result = [[AlarmIntentResult alloc] init];
    NSString *metric = [self watchMetricFromText:text];
    NSString *timeRange = [self timeRangeFromText:text];
    NSDictionary *payload = @{
        @"intent": @"query_device_data",
        @"status": @"ready",
        @"deviceType": @"watch",
        @"originalText": text,
        @"slots": @{
            @"metric": metric,
            @"timeRange": timeRange,
            @"targetUser": @"current",
            @"unit": [self unitForWatchMetric:metric]
        }
    };

    NSString *jsonString = [self jsonStringFromPayload:payload];
    if (jsonString.length == 0) {
        result.assistantText = @"手表数据查询已识别，但生成 JSON 时失败了。";
        result.spokenText = result.assistantText;
        return result;
    }

    result.ready = YES;
    result.jsonString = jsonString;
    result.assistantText = [self mockAssistantTextForWatchPayload:payload];
    result.spokenText = result.assistantText;
    [self submitParsedIntentJSON:jsonString];
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

- (BOOL)isReminderIntentText:(NSString *)text {
    return [self text:text containsAny:@[
        @"闹钟", @"提醒", @"叫我", @"喊我", @"到点", @"记得",
        @"吃药", @"服药", @"用药", @"药", @"喝水", @"起床", @"复诊"
    ]];
}

- (BOOL)isWatchDataQueryIntent:(NSString *)text {
    BOOL hasQueryWord = [self text:text containsAny:@[@"查", @"看", @"看看", @"查询", @"现在", @"今天", @"昨晚", @"最近", @"多少", @"怎么样", @"有没有"]];
    BOOL hasWatchWord = [self text:text containsAny:@[@"手表", @"设备", @"老人", @"家人", @"爸爸", @"妈妈", @"爸", @"妈", @"爷爷", @"奶奶", @"外公", @"外婆"]];
    BOOL hasMetricWord = [self text:text containsAny:@[
        @"心率", @"血氧", @"步数", @"睡眠", @"位置", @"定位", @"电量",
        @"轨迹", @"跌倒", @"离线", @"异常", @"健康", @"运动", @"吃药", @"服药", @"用药"
    ]];
    return hasMetricWord && (hasQueryWord || hasWatchWord);
}

- (NSString *)reminderCategoryFromText:(NSString *)text {
    if ([self text:text containsAny:@[@"吃药", @"服药", @"用药", @"药"]]) {
        return @"medication";
    }
    if ([self text:text containsAny:@[@"闹钟", @"叫我", @"喊我", @"起床"]]) {
        return @"alarm";
    }
    return @"general";
}

- (NSString *)reminderTitleFromText:(NSString *)text category:(NSString *)category {
    if ([category isEqualToString:@"medication"]) {
        if ([text containsString:@"降压药"]) {
            return @"降压药";
        }
        if ([text containsString:@"降糖药"]) {
            return @"降糖药";
        }
        return @"吃药";
    }
    if ([category isEqualToString:@"alarm"]) {
        return [text containsString:@"起床"] ? @"起床" : @"闹钟";
    }
    if ([text containsString:@"喝水"]) {
        return @"喝水";
    }
    if ([text containsString:@"复诊"]) {
        return @"复诊";
    }
    return @"提醒";
}

- (NSString *)parseRepeatFromText:(NSString *)text {
    if ([self text:text containsAny:@[@"每天", @"每日", @"天天"]]) {
        return @"daily";
    }
    if ([self text:text containsAny:@[@"工作日", @"周一到周五", @"星期一到星期五"]]) {
        return @"weekdays";
    }
    if ([self text:text containsAny:@[@"每周", @"每星期"]]) {
        return @"weekly";
    }
    return @"none";
}

- (NSString *)watchMetricFromText:(NSString *)text {
    if ([text containsString:@"心率"]) {
        return @"heart_rate";
    }
    if ([text containsString:@"血氧"]) {
        return @"blood_oxygen";
    }
    if ([self text:text containsAny:@[@"步数", @"运动"]]) {
        return @"steps";
    }
    if ([text containsString:@"睡眠"]) {
        return @"sleep";
    }
    if ([self text:text containsAny:@[@"位置", @"定位", @"轨迹"]]) {
        return @"location";
    }
    if ([text containsString:@"电量"]) {
        return @"battery";
    }
    if ([text containsString:@"跌倒"]) {
        return @"fall_event";
    }
    if ([self text:text containsAny:@[@"吃药", @"服药", @"用药"]]) {
        return @"medication_adherence";
    }
    if ([self text:text containsAny:@[@"离线", @"异常"]]) {
        return @"device_event";
    }
    return @"health_summary";
}

- (NSString *)timeRangeFromText:(NSString *)text {
    if ([self text:text containsAny:@[@"现在", @"当前", @"最新", @"多少"]]) {
        return @"latest";
    }
    if ([text containsString:@"昨晚"]) {
        return @"last_night";
    }
    if ([text containsString:@"昨天"]) {
        return @"yesterday";
    }
    if ([text containsString:@"最近"]) {
        return @"recent";
    }
    if ([text containsString:@"今天"]) {
        return @"today";
    }
    return @"latest";
}

- (NSString *)unitForWatchMetric:(NSString *)metric {
    NSDictionary<NSString *, NSString *> *units = @{
        @"heart_rate": @"bpm",
        @"blood_oxygen": @"%",
        @"steps": @"steps",
        @"battery": @"%",
        @"location": @"geo",
        @"sleep": @"duration",
        @"fall_event": @"event",
        @"device_event": @"event",
        @"medication_adherence": @"record",
        @"health_summary": @"summary"
    };
    return units[metric] ?: @"";
}

- (NSString *)mockAssistantTextForReminderPayload:(NSDictionary *)payload {
    NSDictionary *slots = payload[@"slots"];
    NSString *date = slots[@"date"];
    NSString *time = slots[@"time"];
    NSString *repeat = slots[@"repeat"];
    NSString *title = slots[@"title"];
    NSString *category = payload[@"category"];

    NSString *dateText = [self displayTextForDateString:date];
    NSString *repeatText = [self displayTextForRepeat:repeat];
    NSString *titleText = title.length > 0 ? title : @"提醒";

    if ([repeat isEqualToString:@"none"]) {
        if ([category isEqualToString:@"medication"]) {
            return [NSString stringWithFormat:@"好的，已为你设置%@ %@ 的%@提醒。到点我会提醒。", dateText, time, titleText];
        }
        return [NSString stringWithFormat:@"好的，已为你设置%@ %@ 的%@。", dateText, time, titleText];
    }

    return [NSString stringWithFormat:@"好的，已为你设置%@ %@ 的%@。", repeatText, time, titleText];
}

- (NSString *)mockAssistantTextForWatchPayload:(NSDictionary *)payload {
    NSDictionary *slots = payload[@"slots"];
    NSString *metric = slots[@"metric"];
    NSString *timeRange = slots[@"timeRange"];
    NSString *originalText = payload[@"originalText"];
    NSString *subject = [self mockSubjectFromText:originalText];

    if ([metric isEqualToString:@"heart_rate"]) {
        return [NSString stringWithFormat:@"%@当前心率 78 次/分钟，处于正常范围，数据更新于 1 分钟前。", subject];
    }
    if ([metric isEqualToString:@"blood_oxygen"]) {
        return [NSString stringWithFormat:@"%@当前血氧 97%%，状态正常，数据更新于 2 分钟前。", subject];
    }
    if ([metric isEqualToString:@"steps"]) {
        return [NSString stringWithFormat:@"%@今天已走 6320 步，活动量不错。", subject];
    }
    if ([metric isEqualToString:@"sleep"]) {
        if ([timeRange isEqualToString:@"last_night"] || [timeRange isEqualToString:@"today"]) {
            return [NSString stringWithFormat:@"%@昨晚睡眠 7 小时 20 分钟，深睡 2 小时 05 分钟，整体睡眠质量良好。", subject];
        }
        return [NSString stringWithFormat:@"%@最近睡眠比较稳定，近 7 天平均睡眠 7 小时 10 分钟。", subject];
    }
    if ([metric isEqualToString:@"location"]) {
        return [NSString stringWithFormat:@"%@现在在家附近，距离常用位置约 120 米，定位更新于刚刚。", subject];
    }
    if ([metric isEqualToString:@"battery"]) {
        return [NSString stringWithFormat:@"%@手表当前电量 86%%，预计还能使用 1 天以上。", subject];
    }
    if ([metric isEqualToString:@"fall_event"]) {
        return [NSString stringWithFormat:@"%@最近没有检测到跌倒异常。", subject];
    }
    if ([metric isEqualToString:@"device_event"]) {
        return [NSString stringWithFormat:@"%@手表在线，今天没有离线或设备异常记录。", subject];
    }
    if ([metric isEqualToString:@"medication_adherence"]) {
        return [NSString stringWithFormat:@"%@今天早上的吃药提醒已确认，晚上还有一次待提醒。", subject];
    }

    return [NSString stringWithFormat:@"%@今天健康情况整体平稳：心率 78 次/分钟，血氧 97%%，步数 6320，未发现跌倒或设备异常。", subject];
}

- (NSString *)mockSubjectFromText:(NSString *)text {
    if ([text containsString:@"爸爸"] || [text containsString:@"爸"]) {
        return @"爸爸";
    }
    if ([text containsString:@"妈妈"] || [text containsString:@"妈"]) {
        return @"妈妈";
    }
    if ([text containsString:@"爷爷"]) {
        return @"爷爷";
    }
    if ([text containsString:@"奶奶"]) {
        return @"奶奶";
    }
    if ([text containsString:@"外公"]) {
        return @"外公";
    }
    if ([text containsString:@"外婆"]) {
        return @"外婆";
    }
    if ([text containsString:@"老人"]) {
        return @"老人";
    }
    return @"";
}

- (NSString *)displayTextForDateString:(NSString *)dateString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd";
    NSDate *date = [formatter dateFromString:dateString];
    if (!date) {
        return dateString ?: @"今天";
    }

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *today = [NSDate date];
    NSDate *tomorrow = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:today options:0];
    NSDate *dayAfterTomorrow = [calendar dateByAddingUnit:NSCalendarUnitDay value:2 toDate:today options:0];
    if ([calendar isDate:date inSameDayAsDate:today]) {
        return @"今天";
    }
    if ([calendar isDate:date inSameDayAsDate:tomorrow]) {
        return @"明天";
    }
    if ([calendar isDate:date inSameDayAsDate:dayAfterTomorrow]) {
        return @"后天";
    }
    return dateString;
}

- (NSString *)displayTextForRepeat:(NSString *)repeat {
    if ([repeat isEqualToString:@"daily"]) {
        return @"每天";
    }
    if ([repeat isEqualToString:@"weekdays"]) {
        return @"每个工作日";
    }
    if ([repeat isEqualToString:@"weekly"]) {
        return @"每周";
    }
    return @"";
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

- (NSString *)jsonStringFromPayload:(NSDictionary *)payload {
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&jsonError];
    if (!jsonData || jsonError) {
        return nil;
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (void)submitParsedIntentJSON:(NSString *)jsonString {
    NSLog(@"MOCK submit intent JSON to server: %@", jsonString);
}

@end
