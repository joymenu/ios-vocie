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

typedef NS_ENUM(NSInteger, CallMessageRole) {
    CallMessageRoleUser,
    CallMessageRoleAssistant
};

@interface CallViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, SpeechRecognitionServiceDelegate>

@property (nonatomic, strong) AlarmIntentParser *intentParser;
@property (nonatomic, strong) SpeechRecognitionService *speechService;
@property (nonatomic, strong) SpeechSynthesisService *speechSynthesisService;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *messages;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, copy) NSString *lastFinalSpeechText;

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
    [self appendMessage:@"你好，我是小星。你可以直接说要设置的闹钟。" role:CallMessageRoleAssistant];
    [self speakAssistantText:@"你好，我是小星。你可以直接说要设置的闹钟。"];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.speechService requestAuthorizationWithCompletion:^(BOOL granted, NSString *_Nullable message) {
        if (granted) {
            [self.speechService startListening];
        } else {
            self.statusLabel.text = message ?: @"语音权限不可用";
        }
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
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
    self.textField.placeholder = @"输入或直接说出闹钟需求";
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
    [self handleUserText:self.textField.text];
    self.textField.text = @"";
    [self dismissKeyboard];
}

- (void)handleUserText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedText.length == 0) {
        return;
    }

    [self appendMessage:trimmedText role:CallMessageRoleUser];
    AlarmIntentResult *result = [self.intentParser handleUserText:trimmedText];
    [self appendMessage:result.assistantText role:CallMessageRoleAssistant];
    [self.delegate callViewController:self didReceiveUserText:trimmedText assistantText:result.assistantText];
    [self speakAssistantText:result.spokenText ?: result.assistantText];
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
    [self.speechSynthesisService stopSpeaking];
    [self.speechService stopListening];
    [self.delegate callViewControllerDidClose:self];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)speakAssistantText:(NSString *)text {
    BOOL shouldResumeListening = self.speechService.isListening;
    if (shouldResumeListening) {
        [self.speechService stopListening];
    }

    [self.speechSynthesisService speakText:text completion:^{
        if (shouldResumeListening && self.view.window) {
            [self.speechService startListening];
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
    BOOL isUser = [message[@"role"] integerValue] == CallMessageRoleUser;
    cell.textLabel.text = message[@"text"];
    cell.textLabel.textAlignment = isUser ? NSTextAlignmentRight : NSTextAlignmentLeft;
    cell.textLabel.textColor = isUser ? [UIColor colorWithRed:0.05 green:0.24 blue:0.50 alpha:1.0] : [UIColor colorWithRed:0.08 green:0.14 blue:0.20 alpha:1.0];
    cell.detailTextLabel.text = isUser ? @"我" : @"小星";
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
    self.statusLabel.text = @"正在听你说话";
}

- (void)speechServiceDidStopListening {
    self.statusLabel.text = @"语音监听已暂停";
}

- (void)speechServiceDidRecognizeText:(NSString *)text isFinal:(BOOL)isFinal {
    self.statusLabel.text = [NSString stringWithFormat:@"识别中：%@", text];
    if (!isFinal || [text isEqualToString:self.lastFinalSpeechText]) {
        return;
    }
    self.lastFinalSpeechText = text;
    [self handleUserText:text];
}

- (void)speechServiceDidFailWithMessage:(NSString *)message {
    self.statusLabel.text = message;
}

@end
