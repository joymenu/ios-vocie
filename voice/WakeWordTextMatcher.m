//
//  WakeWordTextMatcher.m
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import "WakeWordTextMatcher.h"

@implementation WakeWordTextMatcher

+ (BOOL)isOnlyWakeWordText:(NSString *)text {
    NSString *normalizedText = [self normalizedTextForWakeWordMatching:text];
    for (NSString *wakeWord in [self wakeWordVariants]) {
        if ([normalizedText isEqualToString:wakeWord]) {
            return YES;
        }
    }
    return NO;
}

+ (NSString *)textByRemovingLeadingWakeWordsFromText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedText.length == 0) {
        return @"";
    }

    NSString *workingText = trimmedText;
    NSRegularExpression *wakeWordExpression = [self leadingWakeWordExpression];
    while (workingText.length > 0) {
        NSTextCheckingResult *match = [wakeWordExpression firstMatchInString:workingText
                                                                     options:0
                                                                       range:NSMakeRange(0, workingText.length)];
        if (!match || match.range.location != 0 || match.range.length == 0) {
            break;
        }

        workingText = [workingText substringFromIndex:NSMaxRange(match.range)];
        workingText = [workingText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }

    return workingText;
}

+ (NSArray<NSString *> *)wakeWordVariants {
    return @[@"小星小星", @"小心小心"];
}

+ (NSString *)normalizedTextForWakeWordMatching:(NSString *)text {
    NSMutableCharacterSet *ignoredCharacters = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
    [ignoredCharacters formUnionWithCharacterSet:NSCharacterSet.punctuationCharacterSet];
    [ignoredCharacters addCharactersInString:@"，。！？、：；“”‘’（）【】《》…"];
    return [[text componentsSeparatedByCharactersInSet:ignoredCharacters] componentsJoinedByString:@""];
}

+ (NSRegularExpression *)leadingWakeWordExpression {
    static NSRegularExpression *expression;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *separatorPattern = @"[\\s\\p{Punct}，。！？、：；“”‘’（）【】《》…]*";
        NSString *pattern = [NSString stringWithFormat:@"^小%@(?:星|心)%@小%@(?:星|心)%@",
                             separatorPattern,
                             separatorPattern,
                             separatorPattern,
                             separatorPattern];
        expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    });
    return expression;
}

@end
