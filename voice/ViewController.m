//
//  ViewController.m
//  voice
//
//  Created by bbu on 2026/5/4.
//

#import "ViewController.h"

#import "AlarmIntentParser.h"
#import "CallViewController.h"
#import "SpeechRecognitionService.h"
#import "SpeechSynthesisService.h"

typedef NS_ENUM(NSInteger, ChatMessageRole) {
    ChatMessageRoleUser,
    ChatMessageRoleAssistant,
    ChatMessageRoleSystem
};

@interface ViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, SpeechRecognitionServiceDelegate, CallViewControllerDelegate>

@property (nonatomic, strong) AlarmIntentParser *intentParser;
@property (nonatomic, strong) SpeechRecognitionService *wakeSpeechService;
@property (nonatomic, strong) SpeechSynthesisService *speechSynthesisService;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *messages;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) BOOL isCallPresented;
@property (nonatomic, assign) BOOL speechAuthorized;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.intentParser = [[AlarmIntentParser alloc] init];
    self.wakeSpeechService = [[SpeechRecognitionService alloc] init];
    self.speechSynthesisService = [[SpeechSynthesisService alloc] init];
    self.wakeSpeechService.delegate = self;
    self.messages = [NSMutableArray array];

    [self setupViews];
    [self appendMessage:@"打开 App 后我会在前台监听“小星小星”。你也可以直接在这里输入闹钟需求。" role:ChatMessageRoleSystem];
    [self requestSpeechPermissionAndStartWakeListening];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.speechAuthorized && !self.isCallPresented && !self.wakeSpeechService.isListening) {
        [self.wakeSpeechService startListening];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (!self.isCallPresented) {
        [self.wakeSpeechService stopListening];
    }
}

- (void)setupViews {
    self.view.backgroundColor = [UIColor colorWithRed:0.97 green:0.98 blue:0.99 alpha:1.0];
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"小星 IM";
    titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor colorWithRed:0.07 green:0.12 blue:0.18 alpha:1.0];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"准备请求语音权限";
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textColor = [UIColor colorWithRed:0.34 green:0.42 blue:0.50 alpha:1.0];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    UIButton *callButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [callButton setTitle:@"通话" forState:UIControlStateNormal];
    callButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    callButton.backgroundColor = [UIColor colorWithRed:0.10 green:0.45 blue:0.92 alpha:1.0];
    [callButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    callButton.layer.cornerRadius = 8;
    [callButton addTarget:self action:@selector(openCallPage) forControlEvents:UIControlEventTouchUpInside];
    callButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:callButton];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
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
    self.textField.placeholder = @"例如：请帮我设置一个明天早8点的闹钟";
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

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:18],
        [titleLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:20],

        [callButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [callButton.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],
        [callButton.widthAnchor constraintEqualToConstant:64],
        [callButton.heightAnchor constraintEqualToConstant:36],

        [self.statusLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:callButton.trailingAnchor],

        [self.tableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:14],
        [self.tableView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:inputBar.topAnchor constant:-10],

        [inputBar.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:14],
        [inputBar.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-14],
        [inputBar.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-10],
        [inputBar.heightAnchor constraintEqualToConstant:54],

        [self.textField.leadingAnchor constraintEqualToAnchor:inputBar.leadingAnchor constant:14],
        [self.textField.centerYAnchor constraintEqualToAnchor:inputBar.centerYAnchor],
        [sendButton.leadingAnchor constraintEqualToAnchor:self.textField.trailingAnchor constant:10],
        [sendButton.trailingAnchor constraintEqualToAnchor:inputBar.trailingAnchor constant:-14],
        [sendButton.centerYAnchor constraintEqualToAnchor:inputBar.centerYAnchor],
        [sendButton.widthAnchor constraintEqualToConstant:48]
    ]];
}

- (void)requestSpeechPermissionAndStartWakeListening {
    [self.wakeSpeechService requestAuthorizationWithCompletion:^(BOOL granted, NSString *_Nullable message) {
        self.speechAuthorized = granted;
        if (granted) {
            [self.wakeSpeechService startListening];
        } else {
            self.statusLabel.text = message ?: @"语音权限不可用";
            [self appendMessage:self.statusLabel.text role:ChatMessageRoleSystem];
        }
    }];
}

- (void)sendTapped {
    [self handleUserText:self.textField.text];
    self.textField.text = @"";
    [self dismissKeyboard];
}

- (void)handleUserText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedText.length == 0) {
        return;
    }

    [self appendMessage:trimmedText role:ChatMessageRoleUser];
    AlarmIntentResult *result = [self.intentParser handleUserText:trimmedText];
    [self appendMessage:result.assistantText role:ChatMessageRoleAssistant];
    [self speakAssistantText:result.spokenText ?: result.assistantText];
}

- (void)appendMessage:(NSString *)text role:(ChatMessageRole)role {
    if (text.length == 0) {
        return;
    }

    [self.messages addObject:@{
        @"text": text,
        @"role": @(role)
    }];
    [self.tableView reloadData];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (void)openCallPage {
    if (self.isCallPresented) {
        return;
    }

    self.isCallPresented = YES;
    [self.wakeSpeechService stopListening];
    CallViewController *callViewController = [[CallViewController alloc] initWithIntentParser:self.intentParser];
    callViewController.delegate = self;
    [self presentViewController:callViewController animated:YES completion:nil];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)speakAssistantText:(NSString *)text {
    BOOL shouldResumeListening = self.speechAuthorized && !self.isCallPresented;
    if (shouldResumeListening) {
        [self.wakeSpeechService stopListening];
    }

    [self.speechSynthesisService speakText:text completion:^{
        if (shouldResumeListening && !self.isCallPresented) {
            [self.wakeSpeechService startListening];
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
    static NSString *reuseIdentifier = @"ChatMessageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = UIColor.clearColor;
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    }

    NSDictionary<NSString *, id> *message = self.messages[indexPath.row];
    ChatMessageRole role = [message[@"role"] integerValue];
    BOOL isUser = role == ChatMessageRoleUser;
    BOOL isSystem = role == ChatMessageRoleSystem;

    cell.textLabel.text = message[@"text"];
    cell.textLabel.textAlignment = isUser ? NSTextAlignmentRight : NSTextAlignmentLeft;
    cell.textLabel.textColor = isSystem
        ? [UIColor colorWithRed:0.45 green:0.50 blue:0.56 alpha:1.0]
        : (isUser ? [UIColor colorWithRed:0.05 green:0.24 blue:0.50 alpha:1.0] : [UIColor colorWithRed:0.08 green:0.14 blue:0.20 alpha:1.0]);
    cell.detailTextLabel.text = isSystem ? @"系统" : (isUser ? @"我" : @"小星");
    cell.detailTextLabel.textAlignment = isUser ? NSTextAlignmentRight : NSTextAlignmentLeft;
    return cell;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self handleUserText:textField.text];
    textField.text = @"";
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - SpeechRecognitionServiceDelegate

- (void)speechServiceDidStartListening {
    self.statusLabel.text = @"前台监听中：请说“小星小星”";
}

- (void)speechServiceDidStopListening {
    self.statusLabel.text = self.isCallPresented ? @"通话中" : @"监听已暂停";
}

- (void)speechServiceDidRecognizeText:(NSString *)text isFinal:(BOOL)isFinal {
    (void)isFinal;
    self.statusLabel.text = [NSString stringWithFormat:@"听到：%@", text];
    if (!self.isCallPresented && [text containsString:@"小星小星"]) {
        [self appendMessage:@"检测到唤醒词“小星小星”，已打开通话页面。" role:ChatMessageRoleSystem];
        [self openCallPage];
    }
}

- (void)speechServiceDidFailWithMessage:(NSString *)message {
    self.statusLabel.text = message;
}

#pragma mark - CallViewControllerDelegate

- (void)callViewController:(CallViewController *)controller didReceiveUserText:(NSString *)userText assistantText:(NSString *)assistantText {
    (void)controller;
    [self appendMessage:userText role:ChatMessageRoleUser];
    [self appendMessage:assistantText role:ChatMessageRoleAssistant];
}

- (void)callViewControllerDidClose:(CallViewController *)controller {
    (void)controller;
    self.isCallPresented = NO;
    [self appendMessage:@"通话已关闭，已回到 IM 聊天窗口。" role:ChatMessageRoleSystem];
    if (self.speechAuthorized) {
        [self.wakeSpeechService startListening];
    }
}

@end
