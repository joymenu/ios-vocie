//
//  CallViewController.m
//  voice
//
//  Created by Codex on 2026/5/4.
//

#import "CallViewController.h"

#import "AlarmIntentParser.h"
#import "SpeechRecognitionService.h"
#import "SpeechSynthesisService.h"
#import "WakeWordTextMatcher.h"

typedef NS_ENUM(NSInteger, CallMessageRole) {
    CallMessageRoleUser,
    CallMessageRoleAssistant
};

@interface CallMessageCell : UITableViewCell

- (void)configureWithText:(NSString *)text role:(CallMessageRole)role;

@end

@interface CallMessageCell ()

@property (nonatomic, strong) UIView *avatarView;
@property (nonatomic, strong) UILabel *avatarLabel;
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) NSLayoutConstraint *avatarLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *avatarTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleLeadingToAvatarConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleTrailingToAvatarConstraint;

@end

@implementation CallMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        [self setupMessageViews];
    }
    return self;
}

- (void)setupMessageViews {
    self.avatarView = [[UIView alloc] init];
    self.avatarView.layer.cornerRadius = 15;
    self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.avatarView];

    self.avatarLabel = [[UILabel alloc] init];
    self.avatarLabel.textAlignment = NSTextAlignmentCenter;
    self.avatarLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    self.avatarLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.avatarView addSubview:self.avatarLabel];

    self.bubbleView = [[UIView alloc] init];
    self.bubbleView.layer.cornerRadius = 8;
    self.bubbleView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.bubbleView];

    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.font = [UIFont systemFontOfSize:15];
    self.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bubbleView addSubview:self.messageLabel];

    self.avatarLeadingConstraint = [self.avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16];
    self.avatarTrailingConstraint = [self.avatarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16];
    self.bubbleLeadingToAvatarConstraint = [self.bubbleView.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:8];
    self.bubbleTrailingToAvatarConstraint = [self.bubbleView.trailingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor constant:-8];

    [NSLayoutConstraint activateConstraints:@[
        [self.avatarView.topAnchor constraintEqualToAnchor:self.bubbleView.topAnchor constant:1],
        [self.avatarView.widthAnchor constraintEqualToConstant:30],
        [self.avatarView.heightAnchor constraintEqualToConstant:30],

        [self.avatarLabel.leadingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor],
        [self.avatarLabel.trailingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor],
        [self.avatarLabel.topAnchor constraintEqualToAnchor:self.avatarView.topAnchor],
        [self.avatarLabel.bottomAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor],

        [self.bubbleView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:7],
        [self.bubbleView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-7],
        [self.bubbleView.widthAnchor constraintLessThanOrEqualToAnchor:self.contentView.widthAnchor multiplier:0.74],

        [self.messageLabel.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:12],
        [self.messageLabel.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-12],
        [self.messageLabel.topAnchor constraintEqualToAnchor:self.bubbleView.topAnchor constant:9],
        [self.messageLabel.bottomAnchor constraintEqualToAnchor:self.bubbleView.bottomAnchor constant:-10]
    ]];
}

- (void)configureWithText:(NSString *)text role:(CallMessageRole)role {
    BOOL isUser = role == CallMessageRoleUser;
    self.messageLabel.text = text;
    self.avatarLabel.text = isUser ? @"我" : @"星";
    self.avatarLabel.textColor = isUser ? UIColor.whiteColor : [UIColor colorWithRed:0.08 green:0.22 blue:0.38 alpha:1.0];
    self.avatarView.backgroundColor = isUser
        ? [UIColor colorWithRed:0.10 green:0.45 blue:0.92 alpha:1.0]
        : [UIColor colorWithRed:0.86 green:0.93 blue:1.0 alpha:1.0];
    self.bubbleView.backgroundColor = isUser
        ? [UIColor colorWithRed:0.10 green:0.45 blue:0.92 alpha:1.0]
        : UIColor.whiteColor;
    self.bubbleView.layer.borderColor = isUser
        ? [UIColor colorWithRed:0.10 green:0.45 blue:0.92 alpha:1.0].CGColor
        : [UIColor colorWithRed:0.86 green:0.90 blue:0.94 alpha:1.0].CGColor;
    self.messageLabel.textColor = isUser ? UIColor.whiteColor : [UIColor colorWithRed:0.08 green:0.14 blue:0.20 alpha:1.0];

    [NSLayoutConstraint deactivateConstraints:@[
        self.avatarLeadingConstraint,
        self.avatarTrailingConstraint,
        self.bubbleLeadingToAvatarConstraint,
        self.bubbleTrailingToAvatarConstraint
    ]];
    [NSLayoutConstraint activateConstraints:isUser
        ? @[self.avatarTrailingConstraint, self.bubbleTrailingToAvatarConstraint]
        : @[self.avatarLeadingConstraint, self.bubbleLeadingToAvatarConstraint]];
}

@end

@interface CallViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, SpeechRecognitionServiceDelegate>

@property (nonatomic, strong) AlarmIntentParser *intentParser;
@property (nonatomic, strong) SpeechRecognitionService *speechService;
@property (nonatomic, strong) SpeechSynthesisService *speechSynthesisService;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *messages;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSLayoutConstraint *inputBarBottomConstraint;
@property (nonatomic, copy) NSString *lastFinalSpeechText;
@property (nonatomic, copy, nullable) NSString *pendingRecognizedText;
@property (nonatomic, copy, nullable) dispatch_block_t recognitionFinishWorkItem;
@property (nonatomic, assign) BOOL speechAuthorized;
@property (nonatomic, assign) BOOL hasPlayedOpeningPrompt;
@property (nonatomic, assign) BOOL closing;

@end

@implementation CallViewController

- (instancetype)initWithIntentParser:(AlarmIntentParser *)intentParser {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _intentParser = intentParser;
        _speechService = [[SpeechRecognitionService alloc] init];
        _speechSynthesisService = [[SpeechSynthesisService alloc] init];
        _messages = [NSMutableArray array];
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.98 blue:1.0 alpha:1.0];
    self.speechService.delegate = self;
    [self setupViews];
    [self appendMessage:@"你好，我是小星。你可以直接说要设置的提醒，也可以查询手表数据。" role:CallMessageRoleAssistant];
    [self.delegate callViewController:self didAppendAssistantText:@"你好，我是小星。你可以直接说要设置的提醒，也可以查询手表数据。"];
    [self registerKeyboardNotifications];
}

- (void)dealloc {
    [self cancelPendingRecognitionFinish];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.speechAuthorized) {
        [self playOpeningPromptIfNeeded];
        return;
    }

    [self.speechService requestAuthorizationWithCompletion:^(BOOL granted, NSString *_Nullable message) {
        self.speechAuthorized = granted;
        if (granted) {
            [self playOpeningPromptIfNeeded];
        } else {
            self.statusLabel.text = message ?: @"语音权限不可用";
        }
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.closing = YES;
    [self cancelPendingRecognitionFinish];
    [self.speechSynthesisService stopSpeaking];
    [self.speechService stopListening];
}

- (void)setupViews {
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    closeButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:closeButton];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"小星通话";
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    titleLabel.textColor = [UIColor colorWithRed:0.08 green:0.14 blue:0.20 alpha:1.0];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];

    UIView *avatarView = [self buildAvatarView];
    avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:avatarView];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"准备监听";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textColor = [UIColor colorWithRed:0.34 green:0.42 blue:0.50 alpha:1.0];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72;
    self.tableView.contentInset = UIEdgeInsetsMake(6, 0, 10, 0);
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:CallMessageCell.class forCellReuseIdentifier:@"CallMessageCell"];
    [self.view addSubview:self.tableView];

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];

    UIView *inputBar = [[UIView alloc] init];
    inputBar.backgroundColor = UIColor.whiteColor;
    inputBar.layer.cornerRadius = 8;
    inputBar.layer.shadowColor = UIColor.blackColor.CGColor;
    inputBar.layer.shadowOpacity = 0.08;
    inputBar.layer.shadowRadius = 10;
    inputBar.layer.shadowOffset = CGSizeMake(0, -2);
    inputBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:inputBar];

    self.textField = [[UITextField alloc] init];
    self.textField.placeholder = @"输入提醒需求或手表数据查询";
    self.textField.font = [UIFont systemFontOfSize:16];
    self.textField.returnKeyType = UIReturnKeySend;
    self.textField.delegate = self;
    self.textField.translatesAutoresizingMaskIntoConstraints = NO;
    [inputBar addSubview:self.textField];

    UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [sendButton setTitle:@"发送" forState:UIControlStateNormal];
    sendButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [sendButton addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
    sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    [inputBar addSubview:sendButton];
    self.inputBarBottomConstraint = [inputBar.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-10];

    [NSLayoutConstraint activateConstraints:@[
        [closeButton.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:12],
        [closeButton.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],
        [closeButton.heightAnchor constraintEqualToConstant:36],

        [titleLabel.centerYAnchor constraintEqualToAnchor:closeButton.centerYAnchor],
        [titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],

        [avatarView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:18],
        [avatarView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [avatarView.widthAnchor constraintEqualToConstant:132],
        [avatarView.heightAnchor constraintEqualToConstant:132],

        [self.statusLabel.topAnchor constraintEqualToAnchor:avatarView.bottomAnchor constant:10],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],

        [self.tableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:10],
        [self.tableView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:inputBar.topAnchor constant:-10],

        [inputBar.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:14],
        [inputBar.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-14],
        self.inputBarBottomConstraint,
        [inputBar.heightAnchor constraintEqualToConstant:54],

        [self.textField.leadingAnchor constraintEqualToAnchor:inputBar.leadingAnchor constant:14],
        [self.textField.centerYAnchor constraintEqualToAnchor:inputBar.centerYAnchor],
        [sendButton.leadingAnchor constraintEqualToAnchor:self.textField.trailingAnchor constant:10],
        [sendButton.trailingAnchor constraintEqualToAnchor:inputBar.trailingAnchor constant:-14],
        [sendButton.centerYAnchor constraintEqualToAnchor:inputBar.centerYAnchor],
        [sendButton.widthAnchor constraintEqualToConstant:48]
    ]];
}

- (void)registerKeyboardNotifications {
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(keyboardWillChangeFrame:)
                                               name:UIKeyboardWillChangeFrameNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(keyboardWillHide:)
                                               name:UIKeyboardWillHideNotification
                                             object:nil];
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [self.view convertRect:keyboardFrame fromView:nil];
    CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardFrameInView));
    CGFloat adjustedOverlap = MAX(0.0, overlap - self.view.safeAreaInsets.bottom);
    [self updateInputBarBottomConstant:-adjustedOverlap - 10 notification:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self updateInputBarBottomConstant:-10 notification:notification];
}

- (void)updateInputBarBottomConstant:(CGFloat)constant notification:(NSNotification *)notification {
    self.inputBarBottomConstraint.constant = constant;
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = ([notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);
    [UIView animateWithDuration:duration delay:0 options:options animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (UIView *)buildAvatarView {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor colorWithRed:0.24 green:0.60 blue:1.0 alpha:1.0];
    container.layer.cornerRadius = 66;

    UILabel *faceLabel = [[UILabel alloc] init];
    faceLabel.text = @"^_^";
    faceLabel.textAlignment = NSTextAlignmentCenter;
    faceLabel.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    faceLabel.textColor = UIColor.whiteColor;
    faceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:faceLabel];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = @"小星";
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    nameLabel.textColor = UIColor.whiteColor;
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:nameLabel];

    [NSLayoutConstraint activateConstraints:@[
        [faceLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [faceLabel.centerYAnchor constraintEqualToAnchor:container.centerYAnchor constant:-12],
        [nameLabel.topAnchor constraintEqualToAnchor:faceLabel.bottomAnchor constant:4],
        [nameLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor]
    ]];

    return container;
}

- (void)sendTapped {
    [self submitCurrentText];
}

- (void)submitCurrentText {
    [self handleUserText:self.textField.text];
    self.textField.text = @"";
}

- (void)handleUserText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedText.length == 0) {
        return;
    }

    NSString *intentText = [WakeWordTextMatcher textByRemovingLeadingWakeWordsFromText:trimmedText];
    BOOL didRemoveWakeWord = ![intentText isEqualToString:trimmedText];
    if ([WakeWordTextMatcher isOnlyWakeWordText:trimmedText] || (didRemoveWakeWord && intentText.length == 0)) {
        self.statusLabel.text = @"已识别到唤醒词，请继续说需求";
        [self beginListeningIfPossible];
        return;
    }

    if (intentText.length == 0) {
        intentText = trimmedText;
    }

    [self appendMessage:intentText role:CallMessageRoleUser];
    self.statusLabel.text = @"正在理解你的需求";
    AlarmIntentResult *result = [self.intentParser handleUserText:intentText];
    [self appendMessage:result.assistantText role:CallMessageRoleAssistant];
    [self.delegate callViewController:self didReceiveUserText:intentText assistantText:result.assistantText];
    [self speakAssistantText:result.spokenText ?: result.assistantText resumeListeningWhenDone:YES];
}

- (void)appendMessage:(NSString *)text role:(CallMessageRole)role {
    [self.messages addObject:@{
        @"text": text,
        @"role": @(role)
    }];
    [self.tableView reloadData];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (void)closeTapped {
    self.closing = YES;
    [self cancelPendingRecognitionFinish];
    [self.speechSynthesisService stopSpeaking];
    [self.speechService stopListening];
    [self.delegate callViewControllerDidClose:self];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)playOpeningPromptIfNeeded {
    if (self.hasPlayedOpeningPrompt) {
        [self beginListeningIfPossible];
        return;
    }

    self.hasPlayedOpeningPrompt = YES;
    [self speakAssistantText:@"你好，我是小星。你可以直接说要设置的提醒，也可以查询手表数据。" resumeListeningWhenDone:YES];
}

- (void)beginListeningIfPossible {
    if (!self.speechAuthorized || self.closing || !self.view.window || self.speechService.isListening || self.speechSynthesisService.isSpeaking) {
        return;
    }
    self.pendingRecognizedText = nil;
    [self.speechService startListening];
}

- (void)speakAssistantText:(NSString *)text resumeListeningWhenDone:(BOOL)resumeListening {
    if (self.speechService.isListening) {
        [self.speechService stopListening];
    }

    self.statusLabel.text = @"小星正在说话";
    [self.speechSynthesisService speakText:text completion:^{
        if (resumeListening) {
            [self beginListeningIfPossible];
        } else if (!self.closing) {
            self.statusLabel.text = @"语音监听已暂停";
        }
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuseIdentifier = @"CallMessageCell";
    CallMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];

    NSDictionary<NSString *, id> *message = self.messages[indexPath.row];
    CallMessageRole role = [message[@"role"] integerValue];
    [cell configureWithText:message[@"text"] role:role];
    return cell;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self submitCurrentText];
    return NO;
}

#pragma mark - SpeechRecognitionServiceDelegate

- (void)speechServiceDidStartListening {
    [self cancelPendingRecognitionFinish];
    self.pendingRecognizedText = nil;
    self.statusLabel.text = @"正在听你说话，说完后我会自动回复";
}

- (void)speechServiceDidStopListening {
    if (!self.speechSynthesisService.isSpeaking && !self.closing) {
        self.statusLabel.text = @"语音监听已暂停";
    }
}

- (void)speechServiceDidRecognizeText:(NSString *)text isFinal:(BOOL)isFinal {
    if (self.speechSynthesisService.isSpeaking) {
        return;
    }
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([WakeWordTextMatcher isOnlyWakeWordText:trimmedText]) {
        self.statusLabel.text = @"已识别到唤醒词，请继续说需求";
    } else {
        self.statusLabel.text = [NSString stringWithFormat:@"识别中：%@", text];
    }
    if (!isFinal) {
        [self scheduleRecognitionFinishForText:text];
        return;
    }
    [self cancelPendingRecognitionFinish];
    [self finishRecognizedText:text];
}

- (void)speechServiceDidFailWithMessage:(NSString *)message {
    [self cancelPendingRecognitionFinish];
    self.statusLabel.text = message;
}

- (void)scheduleRecognitionFinishForText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedText.length == 0) {
        return;
    }

    [self cancelPendingRecognitionFinish];
    self.pendingRecognizedText = trimmedText;
    __weak typeof(self) weakSelf = self;
    dispatch_block_t workItem = dispatch_block_create(0, ^{
        [weakSelf finishPendingRecognizedTextIfNeeded];
    });
    self.recognitionFinishWorkItem = workItem;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), workItem);
}

- (void)finishPendingRecognizedTextIfNeeded {
    NSString *text = self.pendingRecognizedText;
    self.pendingRecognizedText = nil;
    self.recognitionFinishWorkItem = nil;
    [self finishRecognizedText:text];
}

- (void)finishRecognizedText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedText.length == 0 || [trimmedText isEqualToString:self.lastFinalSpeechText]) {
        return;
    }

    self.lastFinalSpeechText = trimmedText;
    if ([WakeWordTextMatcher isOnlyWakeWordText:trimmedText]) {
        self.statusLabel.text = @"已识别到唤醒词，请继续说需求";
        [self beginListeningIfPossible];
        return;
    }

    self.statusLabel.text = @"你说完了，小星正在处理";
    [self handleUserText:trimmedText];
}

- (void)cancelPendingRecognitionFinish {
    if (self.recognitionFinishWorkItem) {
        dispatch_block_cancel(self.recognitionFinishWorkItem);
        self.recognitionFinishWorkItem = nil;
    }
    self.pendingRecognizedText = nil;
}

@end
