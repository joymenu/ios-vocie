//
//  AlarmIntentParser.h
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AlarmIntentResult : NSObject

@property (nonatomic, copy) NSString *assistantText;
@property (nonatomic, copy) NSString *spokenText;
@property (nonatomic, copy, nullable) NSString *jsonString;
@property (nonatomic, assign, getter=isReady) BOOL ready;

@end

@interface AlarmIntentParser : NSObject

- (AlarmIntentResult *)handleUserText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
