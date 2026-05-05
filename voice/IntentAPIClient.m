//
//  IntentAPIClient.m
//  voice
//
//  Created by Codex on 2026/5/5.
//

#import "IntentAPIClient.h"

#import <CommonCrypto/CommonDigest.h>

static NSString * const IntentAPIErrorDomain = @"com.fuyunhealth.voice.intent-api";
static NSString * const IntentAPIDefaultBaseURLString = @"https://uat.stg.fuyunhealth.com";
static NSString * const IntentAPISignSecret = @"fuyunhealth.com";

@implementation IntentAPIResult
@end

@implementation IntentAPIClient

- (void)parseIntentWithText:(NSString *)text completion:(IntentAPICompletion)completion {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedText.length == 0) {
        if (completion) {
            completion(nil, [self errorWithCode:-1 message:@"text is empty"]);
        }
        return;
    }

    NSMutableDictionary<NSString *, NSString *> *parameters = [@{
        @"text": trimmedText,
        @"channel": [self channel],
        @"ts": [NSString stringWithFormat:@"%.0f", NSDate.date.timeIntervalSince1970 * 1000.0],
        @"locale": @"zh-CN",
        @"timezone": NSTimeZone.localTimeZone.name ?: @"Asia/Shanghai"
    } mutableCopy];
    parameters[@"sign"] = [self signForParameters:parameters];

    NSURL *url = [self requestURLWithParameters:parameters];
    if (!url) {
        if (completion) {
            completion(nil, [self errorWithCode:-2 message:@"invalid url"]);
        }
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 15.0;
    [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];

    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request
                                                               completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        if (error) {
            [self completeOnMain:completion result:nil error:error];
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (![httpResponse isKindOfClass:NSHTTPURLResponse.class] || httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
            [self completeOnMain:completion result:nil error:[self errorWithCode:httpResponse.statusCode message:@"bad http status"]];
            return;
        }

        if (data.length == 0) {
            [self completeOnMain:completion result:nil error:[self errorWithCode:-3 message:@"empty response"]];
            return;
        }

        NSError *jsonError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError || ![json isKindOfClass:NSDictionary.class]) {
            [self completeOnMain:completion result:nil error:jsonError ?: [self errorWithCode:-4 message:@"invalid response json"]];
            return;
        }

        NSDictionary *responseObject = (NSDictionary *)json;
        if (![responseObject[@"success"] boolValue]) {
            NSString *message = [responseObject[@"msg"] isKindOfClass:NSString.class] ? responseObject[@"msg"] : @"server failure";
            [self completeOnMain:completion result:nil error:[self errorWithCode:[responseObject[@"code"] integerValue] message:message]];
            return;
        }

        NSDictionary *content = [responseObject[@"content"] isKindOfClass:NSDictionary.class] ? responseObject[@"content"] : nil;
        IntentAPIResult *result = [self resultFromContent:content];
        if (!result) {
            [self completeOnMain:completion result:nil error:[self errorWithCode:-5 message:@"invalid response content"]];
            return;
        }

        [self completeOnMain:completion result:result error:nil];
    }];
    [task resume];
}

- (IntentAPIResult *_Nullable)resultFromContent:(NSDictionary *_Nullable)content {
    if (!content) {
        return nil;
    }
    NSString *displayText = [content[@"displayText"] isKindOfClass:NSString.class] ? content[@"displayText"] : nil;
    if (displayText.length == 0) {
        return nil;
    }

    IntentAPIResult *result = [[IntentAPIResult alloc] init];
    result.displayText = displayText;
    result.spokenText = [content[@"spokenText"] isKindOfClass:NSString.class] && [content[@"spokenText"] length] > 0 ? content[@"spokenText"] : displayText;
    result.intent = [content[@"intent"] isKindOfClass:NSString.class] ? content[@"intent"] : nil;
    result.status = [content[@"status"] isKindOfClass:NSString.class] ? content[@"status"] : nil;
    result.source = [content[@"source"] isKindOfClass:NSString.class] ? content[@"source"] : nil;
    result.slots = [content[@"slots"] isKindOfClass:NSDictionary.class] ? content[@"slots"] : nil;
    return result;
}

- (NSURL *_Nullable)requestURLWithParameters:(NSDictionary<NSString *, NSString *> *)parameters {
    NSURL *baseURL = [NSURL URLWithString:[self baseURLString]];
    if (!baseURL) {
        return nil;
    }

    NSURLComponents *components = [NSURLComponents componentsWithURL:[baseURL URLByAppendingPathComponent:@"ai/xiaoxing/parseIntent"]
                                             resolvingAgainstBaseURL:NO];
    NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray array];
    NSArray<NSString *> *keys = [[parameters allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *key in keys) {
        [queryItems addObject:[NSURLQueryItem queryItemWithName:key value:parameters[key]]];
    }
    components.queryItems = queryItems;
    return components.URL;
}

- (NSString *)baseURLString {
    NSString *value = NSBundle.mainBundle.infoDictionary[@"XiaoXingBackendBaseURL"];
    if ([value isKindOfClass:NSString.class] && value.length > 0) {
        return value;
    }
    return IntentAPIDefaultBaseURLString;
}

- (NSString *)channel {
    NSString *value = NSBundle.mainBundle.infoDictionary[@"XiaoXingBackendChannel"];
    if ([value isKindOfClass:NSString.class] && value.length > 0) {
        return value;
    }
    return @"ios-voice";
}

- (NSString *)signForParameters:(NSDictionary<NSString *, NSString *> *)parameters {
    NSArray<NSString *> *keys = [[parameters allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableString *source = [NSMutableString string];
    for (NSString *key in keys) {
        if ([key isEqualToString:@"sign"]) {
            continue;
        }
        [source appendString:key];
        [source appendString:parameters[key] ?: @""];
    }
    [source appendString:IntentAPISignSecret];

    NSData *sourceData = [source dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64String = [sourceData base64EncodedStringWithOptions:0];
    NSData *base64Data = [base64String dataUsingEncoding:NSUTF8StringEncoding];

    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(base64Data.bytes, (CC_LONG)base64Data.length, digest);

    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (NSInteger i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:IntentAPIErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"request failed"}];
}

- (void)completeOnMain:(IntentAPICompletion)completion result:(IntentAPIResult *_Nullable)result error:(NSError *_Nullable)error {
    if (!completion) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(result, error);
    });
}

@end
