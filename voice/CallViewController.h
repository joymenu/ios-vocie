//
//  CallViewController.h
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import <UIKit/UIKit.h>

@class AlarmIntentParser;
@class CallViewController;

NS_ASSUME_NONNULL_BEGIN

@protocol CallViewControllerDelegate <NSObject>

- (void)callViewController:(CallViewController *)controller didReceiveUserText:(NSString *)userText assistantText:(NSString *)assistantText;
- (void)callViewControllerDidClose:(CallViewController *)controller;

@end

@interface CallViewController : UIViewController

@property (nonatomic, weak, nullable) id<CallViewControllerDelegate> delegate;

- (instancetype)initWithIntentParser:(AlarmIntentParser *)intentParser;

@end

NS_ASSUME_NONNULL_END
