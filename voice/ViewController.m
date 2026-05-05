//
//  ViewController.m
//  voice
//
//  Created by bbu on 2026/5/4.
//

#import "ViewController.h"

#import "AlarmIntentParser.h"
#import "CallViewController.h"
#import "IFlytekAIKitWakeWordDetector.h"
#import "IntentAPIClient.h"
#import "LocalWakeWordService.h"
#import "SpeechRecognitionService.h"
#import "SpeechSynthesisService.h"
#import "WakeWordTextMatcher.h"

typedef NS_ENUM(NSInteger, ChatMessageRole) {
    ChatMessageRoleUser,
    ChatMessageRoleAssistant,
    ChatMessageRoleSystem
};

static NSString * const XiaoXingWelcomeShownKey = @"XiaoXingWelcomeShownKey";
static NSString * const ChatMessageTypeWelcome = @"welcome";

@interface ChatMessageCell : UITableViewCell

- (void)configureWithText:(NSString *)text role:(ChatMessageRole)role;

@end

@interface XiaoXingWelcomeCell : UITableViewCell

- (void)configure;

@end

@interface ChatMessageCell ()

@property (nonatomic, strong) UIView *avatarView;
@property (nonatomic, strong) UILabel *avatarLabel;
@property (nonatomic, strong) UIImageView *avatarIconView;
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UIStackView *textStackView;
@property (nonatomic, strong) UILabel *roleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) NSLayoutConstraint *avatarLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *avatarTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleLeadingToAvatarConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleTrailingToAvatarConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleCenterXConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleSystemLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleSystemTrailingConstraint;

@end

@implementation ChatMessageCell

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

    self.avatarIconView = [[UIImageView alloc] init];
    self.avatarIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.avatarIconView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.avatarView addSubview:self.avatarIconView];

    self.bubbleView = [[UIView alloc] init];
    self.bubbleView.layer.cornerRadius = 8;
    self.bubbleView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.bubbleView];

    self.roleLabel = [[UILabel alloc] init];
    self.roleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.roleLabel.textColor = [UIColor colorWithRed:0.39 green:0.46 blue:0.54 alpha:1.0];

    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.font = [UIFont systemFontOfSize:15];
    self.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;

    self.textStackView = [[UIStackView alloc] initWithArrangedSubviews:@[self.roleLabel, self.messageLabel]];
    self.textStackView.axis = UILayoutConstraintAxisVertical;
    self.textStackView.spacing = 3;
    self.textStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bubbleView addSubview:self.textStackView];

    self.avatarLeadingConstraint = [self.avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16];
    self.avatarTrailingConstraint = [self.avatarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16];
    self.bubbleLeadingToAvatarConstraint = [self.bubbleView.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:8];
    self.bubbleTrailingToAvatarConstraint = [self.bubbleView.trailingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor constant:-8];
    self.bubbleCenterXConstraint = [self.bubbleView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor];
    self.bubbleSystemLeadingConstraint = [self.bubbleView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:40];
    self.bubbleSystemTrailingConstraint = [self.bubbleView.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-40];

    [NSLayoutConstraint activateConstraints:@[
        [self.avatarView.topAnchor constraintEqualToAnchor:self.bubbleView.topAnchor constant:2],
        [self.avatarView.widthAnchor constraintEqualToConstant:30],
        [self.avatarView.heightAnchor constraintEqualToConstant:30],

        [self.avatarLabel.leadingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor],
        [self.avatarLabel.trailingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor],
        [self.avatarLabel.topAnchor constraintEqualToAnchor:self.avatarView.topAnchor],
        [self.avatarLabel.bottomAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor],

        [self.avatarIconView.centerXAnchor constraintEqualToAnchor:self.avatarView.centerXAnchor],
        [self.avatarIconView.centerYAnchor constraintEqualToAnchor:self.avatarView.centerYAnchor],
        [self.avatarIconView.widthAnchor constraintEqualToConstant:16],
        [self.avatarIconView.heightAnchor constraintEqualToConstant:16],

        [self.bubbleView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:7],
        [self.bubbleView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-7],
        [self.bubbleView.widthAnchor constraintLessThanOrEqualToAnchor:self.contentView.widthAnchor multiplier:0.74],

        [self.textStackView.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:12],
        [self.textStackView.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-12],
        [self.textStackView.topAnchor constraintEqualToAnchor:self.bubbleView.topAnchor constant:9],
        [self.textStackView.bottomAnchor constraintEqualToAnchor:self.bubbleView.bottomAnchor constant:-10]
    ]];
}

- (void)configureWithText:(NSString *)text role:(ChatMessageRole)role {
    self.messageLabel.text = text;
    self.roleLabel.hidden = role == ChatMessageRoleSystem;
    self.avatarView.hidden = role == ChatMessageRoleSystem;

    [NSLayoutConstraint deactivateConstraints:@[
        self.avatarLeadingConstraint,
        self.avatarTrailingConstraint,
        self.bubbleLeadingToAvatarConstraint,
        self.bubbleTrailingToAvatarConstraint,
        self.bubbleCenterXConstraint,
        self.bubbleSystemLeadingConstraint,
        self.bubbleSystemTrailingConstraint
    ]];

    if (role == ChatMessageRoleUser) {
        self.roleLabel.text = @"客户";
        self.avatarLabel.text = @"";
        self.avatarIconView.hidden = NO;
        self.avatarIconView.image = [UIImage systemImageNamed:@"person.fill"];
        self.avatarIconView.tintColor = UIColor.whiteColor;
        self.avatarView.backgroundColor = [UIColor colorWithRed:0.10 green:0.45 blue:0.92 alpha:1.0];
        self.bubbleView.backgroundColor = [UIColor colorWithRed:0.10 green:0.45 blue:0.92 alpha:1.0];
        self.bubbleView.layer.borderColor = [UIColor colorWithRed:0.10 green:0.45 blue:0.92 alpha:1.0].CGColor;
        self.messageLabel.textColor = UIColor.whiteColor;
        self.messageLabel.textAlignment = NSTextAlignmentLeft;
        self.roleLabel.textAlignment = NSTextAlignmentRight;
        self.roleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.78];
        [NSLayoutConstraint activateConstraints:@[
            self.avatarTrailingConstraint,
            self.bubbleTrailingToAvatarConstraint
        ]];
    } else if (role == ChatMessageRoleAssistant) {
        self.roleLabel.text = @"小星";
        self.avatarLabel.text = @"";
        self.avatarIconView.hidden = NO;
        self.avatarIconView.image = [UIImage systemImageNamed:@"sparkles"];
        self.avatarIconView.tintColor = [UIColor colorWithRed:0.08 green:0.22 blue:0.38 alpha:1.0];
        self.avatarView.backgroundColor = [UIColor colorWithRed:0.86 green:0.93 blue:1.0 alpha:1.0];
        self.bubbleView.backgroundColor = UIColor.whiteColor;
        self.bubbleView.layer.borderColor = [UIColor colorWithRed:0.86 green:0.90 blue:0.94 alpha:1.0].CGColor;
        self.messageLabel.textColor = [UIColor colorWithRed:0.08 green:0.14 blue:0.20 alpha:1.0];
        self.messageLabel.textAlignment = NSTextAlignmentLeft;
        self.roleLabel.textAlignment = NSTextAlignmentLeft;
        self.roleLabel.textColor = [UIColor colorWithRed:0.39 green:0.46 blue:0.54 alpha:1.0];
        [NSLayoutConstraint activateConstraints:@[
            self.avatarLeadingConstraint,
            self.bubbleLeadingToAvatarConstraint
        ]];
    } else {
        self.avatarIconView.hidden = YES;
        self.bubbleView.backgroundColor = [UIColor colorWithRed:0.91 green:0.94 blue:0.97 alpha:1.0];
        self.bubbleView.layer.borderColor = [UIColor colorWithRed:0.84 green:0.88 blue:0.92 alpha:1.0].CGColor;
        self.messageLabel.textColor = [UIColor colorWithRed:0.38 green:0.45 blue:0.53 alpha:1.0];
        self.messageLabel.textAlignment = NSTextAlignmentCenter;
        [NSLayoutConstraint activateConstraints:@[
            self.avatarLeadingConstraint,
            self.bubbleCenterXConstraint,
            self.bubbleSystemLeadingConstraint,
            self.bubbleSystemTrailingConstraint
        ]];
    }
}

@end

@implementation XiaoXingWelcomeCell {
    UIView *_cardView;
    UILabel *_titleLabel;
    UILabel *_bodyLabel;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    _cardView = [[UIView alloc] init];
    _cardView.backgroundColor = UIColor.whiteColor;
    _cardView.layer.cornerRadius = 8;
    _cardView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _cardView.layer.borderColor = [UIColor colorWithRed:0.82 green:0.88 blue:0.94 alpha:1.0].CGColor;
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_cardView];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles"]];
    iconView.tintColor = [UIColor colorWithRed:0.10 green:0.45 blue:0.92 alpha:1.0];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardView addSubview:iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    _titleLabel.textColor = [UIColor colorWithRed:0.07 green:0.12 blue:0.18 alpha:1.0];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardView addSubview:_titleLabel];

    _bodyLabel = [[UILabel alloc] init];
    _bodyLabel.numberOfLines = 0;
    _bodyLabel.font = [UIFont systemFontOfSize:14];
    _bodyLabel.textColor = [UIColor colorWithRed:0.24 green:0.31 blue:0.39 alpha:1.0];
    _bodyLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardView addSubview:_bodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],

        [iconView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:16],
        [iconView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:16],
        [iconView.widthAnchor constraintEqualToConstant:22],
        [iconView.heightAnchor constraintEqualToConstant:22],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:8],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:iconView.centerYAnchor],

        [_bodyLabel.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:16],
        [_bodyLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16],
        [_bodyLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:12],
        [_bodyLabel.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-16]
    ]];
}

- (void)configure {
    _titleLabel.text = @"你好，我是小星";
    _bodyLabel.text = @"我可以帮你设置吃药、闹钟和日程提醒，也可以查询心率、血氧、步数、睡眠、位置、电量、跌倒异常等手表信息，并继续追问。\n\n你可以这样说：\n明天早上8点提醒我吃药\n查一下现在心率\n最近有没有跌倒异常\n\nAI 理解可能需要联网；健康解释仅供参考，异常或紧急情况请优先联系医生或急救。你也可以说“小星小星”进入语音通话。";
}

@end

@interface ViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, LocalWakeWordServiceDelegate, SpeechRecognitionServiceDelegate, CallViewControllerDelegate>

@property (nonatomic, strong) AlarmIntentParser *intentParser;
@property (nonatomic, strong) IntentAPIClient *intentAPIClient;
@property (nonatomic, strong, nullable) LocalWakeWordService *wakeWordService;
@property (nonatomic, strong, nullable) SpeechRecognitionService *wakeSpeechService;
@property (nonatomic, strong) SpeechSynthesisService *speechSynthesisService;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *messages;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *intentRequestIndicator;
@property (nonatomic, strong) NSLayoutConstraint *inputBarBottomConstraint;
@property (nonatomic, assign) BOOL isCallPresented;
@property (nonatomic, assign) BOOL wakeAuthorized;
@property (nonatomic, assign) BOOL usesSpeechWakeFallback;
@property (nonatomic, assign) BOOL wakeSpeechDetected;
@property (nonatomic, copy) NSString *lastWakeSpeechText;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.intentParser = [[AlarmIntentParser alloc] init];
    self.intentAPIClient = [[IntentAPIClient alloc] init];
    id<LocalWakeWordDetecting> wakeDetector = [IFlytekAIKitWakeWordDetector detectorIfReady];
    NSString *wakeStatusMessage = nil;
    if (wakeDetector) {
        wakeStatusMessage = ((IFlytekAIKitWakeWordDetector *)wakeDetector).statusMessage;
        self.wakeWordService = [[LocalWakeWordService alloc] initWithDetector:wakeDetector];
        self.wakeWordService.delegate = self;
    } else {
        self.usesSpeechWakeFallback = YES;
        self.wakeSpeechService = [[SpeechRecognitionService alloc] init];
        self.wakeSpeechService.delegate = self;
        self.wakeSpeechService.reportsPartialResults = YES;
        self.wakeSpeechService.maximumSessionDuration = 55;
        self.wakeSpeechService.restartDelay = 0.2;
        wakeStatusMessage = [IFlytekAIKitWakeWordDetector integrationStatusMessage];
    }
    self.speechSynthesisService = [[SpeechSynthesisService alloc] init];
    self.messages = [NSMutableArray array];

    [self setupViews];
    [self registerKeyboardNotifications];
    [self appendWelcomeCardIfNeeded];
    [self appendMessage:wakeStatusMessage role:ChatMessageRoleSystem];
    [self requestWakePermissionAndStartListening];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.wakeAuthorized && !self.isCallPresented && ![self isWakeListening]) {
        [self startWakeListening];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (!self.isCallPresented) {
        [self stopWakeListening];
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

    self.intentRequestIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.intentRequestIndicator.hidesWhenStopped = YES;
    self.intentRequestIndicator.translatesAutoresizingMaskIntoConstraints = NO;

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"准备请求语音权限";
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textColor = [UIColor colorWithRed:0.34 green:0.42 blue:0.50 alpha:1.0];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *statusRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.intentRequestIndicator, self.statusLabel]];
    statusRow.axis = UILayoutConstraintAxisHorizontal;
    statusRow.alignment = UIStackViewAlignmentCenter;
    statusRow.spacing = 8;
    statusRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:statusRow];

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
    self.tableView.contentInset = UIEdgeInsetsMake(6, 0, 10, 0);
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:ChatMessageCell.class forCellReuseIdentifier:@"ChatMessageCell"];
    [self.tableView registerClass:XiaoXingWelcomeCell.class forCellReuseIdentifier:@"XiaoXingWelcomeCell"];
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
    self.textField.placeholder = @"问小星：提醒吃药、查心率、看睡眠...";
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
        [titleLabel.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:18],
        [titleLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:20],

        [callButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [callButton.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],
        [callButton.widthAnchor constraintEqualToConstant:64],
        [callButton.heightAnchor constraintEqualToConstant:36],

        [statusRow.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
        [statusRow.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [statusRow.trailingAnchor constraintEqualToAnchor:callButton.trailingAnchor],

        [self.tableView.topAnchor constraintEqualToAnchor:statusRow.bottomAnchor constant:14],
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

- (void)requestWakePermissionAndStartListening {
    void (^completion)(BOOL, NSString *_Nullable) = ^(BOOL granted, NSString *_Nullable message) {
        self.wakeAuthorized = granted;
        if (granted) {
            [self startWakeListening];
        } else {
            self.statusLabel.text = message ?: @"语音权限不可用";
            [self appendMessage:self.statusLabel.text role:ChatMessageRoleSystem];
        }
    };

    if (self.usesSpeechWakeFallback) {
        [self.wakeSpeechService requestAuthorizationWithCompletion:completion];
    } else {
        [self.wakeWordService requestMicrophonePermissionWithCompletion:completion];
    }
}

- (BOOL)isWakeListening {
    if (self.usesSpeechWakeFallback) {
        return self.wakeSpeechService.isListening;
    }
    return self.wakeWordService.isListening;
}

- (void)startWakeListening {
    self.wakeSpeechDetected = NO;
    self.lastWakeSpeechText = @"";
    if (self.usesSpeechWakeFallback) {
        [self.wakeSpeechService startListening];
    } else {
        [self.wakeWordService startListening];
    }
}

- (void)stopWakeListening {
    if (self.usesSpeechWakeFallback) {
        [self.wakeSpeechService stopListening];
    } else {
        [self.wakeWordService stopListening];
    }
}

- (void)sendTapped {
    [self submitCurrentText];
}

- (void)appendWelcomeCardIfNeeded {
    if ([NSUserDefaults.standardUserDefaults boolForKey:XiaoXingWelcomeShownKey]) {
        return;
    }
    [self.messages addObject:@{@"type": ChatMessageTypeWelcome}];
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:XiaoXingWelcomeShownKey];
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
        self.statusLabel.text = @"文本唤醒已触发，正在打开通话";
        [self appendMessage:@"已识别到唤醒词，正在打开通话。" role:ChatMessageRoleSystem];
        [self openCallPage];
        return;
    }

    if (intentText.length == 0) {
        intentText = trimmedText;
    }

    [self appendMessage:intentText role:ChatMessageRoleUser];
    [self requestRemoteIntentForText:intentText];
}

- (void)requestRemoteIntentForText:(NSString *)intentText {
    self.statusLabel.text = @"正在请求服务端理解你的需求，请稍候…";
    [self.intentRequestIndicator startAnimating];
    __weak typeof(self) weakSelf = self;
    [self.intentAPIClient parseIntentWithText:intentText completion:^(IntentAPIResult *_Nullable apiResult, NSError *_Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self) {
            [self.intentRequestIndicator stopAnimating];
        }
        if (!self) {
            return;
        }

        NSString *assistantText = apiResult.displayText;
        NSString *spokenText = apiResult.spokenText;
        if (assistantText.length == 0 || error) {
            NSString *detail = [IntentAPIClient localizedSummaryForIntentAPIError:error];
            const NSUInteger kMaxIntentFailureDetailLength = 200;
            if (detail.length > kMaxIntentFailureDetailLength) {
                detail = [[detail substringToIndex:kMaxIntentFailureDetailLength] stringByAppendingString:@"…"];
            }
            [self appendMessage:[NSString stringWithFormat:@"服务端请求失败：%@", detail] role:ChatMessageRoleSystem];
            AlarmIntentResult *localResult = [self.intentParser handleUserText:intentText];
            assistantText = localResult.assistantText;
            spokenText = localResult.spokenText ?: localResult.assistantText;
            self.statusLabel.text = @"服务端请求失败，已改用本地回复";
        } else {
            self.statusLabel.text = @"小星已回复";
        }

        [self appendMessage:assistantText role:ChatMessageRoleAssistant];
        [self speakAssistantText:spokenText ?: assistantText];
    }];
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
    [self stopWakeListening];
    CallViewController *callViewController = [[CallViewController alloc] initWithIntentParser:self.intentParser];
    callViewController.delegate = self;
    [self presentViewController:callViewController animated:YES completion:nil];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)speakAssistantText:(NSString *)text {
    BOOL shouldResumeListening = self.wakeAuthorized && !self.isCallPresented;
    if (shouldResumeListening) {
        [self stopWakeListening];
    }

    [self.speechSynthesisService speakText:text completion:^{
        if (shouldResumeListening && !self.isCallPresented) {
            [self startWakeListening];
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
    NSDictionary<NSString *, id> *message = self.messages[indexPath.row];
    if ([message[@"type"] isEqualToString:ChatMessageTypeWelcome]) {
        XiaoXingWelcomeCell *cell = [tableView dequeueReusableCellWithIdentifier:@"XiaoXingWelcomeCell" forIndexPath:indexPath];
        [cell configure];
        return cell;
    }

    static NSString *reuseIdentifier = @"ChatMessageCell";
    ChatMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    ChatMessageRole role = [message[@"role"] integerValue];
    [cell configureWithText:message[@"text"] role:role];
    return cell;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self submitCurrentText];
    return NO;
}

#pragma mark - LocalWakeWordServiceDelegate

- (void)localWakeWordServiceDidStartListening {
    self.statusLabel.text = @"本地唤醒监听中：请说“小星小星”";
}

- (void)localWakeWordServiceDidStopListening {
    self.statusLabel.text = self.isCallPresented ? @"通话中" : @"监听已暂停";
}

- (void)localWakeWordServiceDidDetectWakeWordWithReason:(NSString *)reason {
    if (self.isCallPresented) {
        return;
    }
    self.statusLabel.text = @"已唤醒，正在打开通话";
    [self appendMessage:[NSString stringWithFormat:@"本地唤醒引擎已触发：%@", reason] role:ChatMessageRoleSystem];
    [self openCallPage];
}

- (void)localWakeWordServiceDidFailWithMessage:(NSString *)message {
    self.statusLabel.text = message;
}

#pragma mark - SpeechRecognitionServiceDelegate

- (void)speechServiceDidStartListening {
    self.statusLabel.text = @"开发唤醒监听中：请说“小星小星”";
}

- (void)speechServiceDidStopListening {
    self.statusLabel.text = self.isCallPresented ? @"通话中" : @"监听已暂停";
}

- (void)speechServiceDidRecognizeText:(NSString *)text isFinal:(BOOL)isFinal {
    (void)isFinal;
    if (!self.usesSpeechWakeFallback || self.wakeSpeechDetected || self.isCallPresented) {
        return;
    }

    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedText.length == 0 || [trimmedText isEqualToString:self.lastWakeSpeechText]) {
        return;
    }

    self.lastWakeSpeechText = trimmedText;
    self.statusLabel.text = [NSString stringWithFormat:@"识别中：%@", trimmedText];
    NSString *intentText = [WakeWordTextMatcher textByRemovingLeadingWakeWordsFromText:trimmedText];
    BOOL didRemoveWakeWord = ![intentText isEqualToString:trimmedText];
    if (![WakeWordTextMatcher isOnlyWakeWordText:trimmedText] && !didRemoveWakeWord) {
        return;
    }

    self.wakeSpeechDetected = YES;
    self.statusLabel.text = @"已唤醒，正在打开通话";
    [self appendMessage:[NSString stringWithFormat:@"开发语音唤醒已触发：%@", trimmedText] role:ChatMessageRoleSystem];
    [self openCallPage];
}

- (void)speechServiceDidFailWithMessage:(NSString *)message {
    self.statusLabel.text = message;
    [self appendMessage:message role:ChatMessageRoleSystem];
}

#pragma mark - CallViewControllerDelegate

- (void)callViewController:(CallViewController *)controller didReceiveUserText:(NSString *)userText assistantText:(NSString *)assistantText {
    (void)controller;
    [self appendMessage:userText role:ChatMessageRoleUser];
    [self appendMessage:assistantText role:ChatMessageRoleAssistant];
}

- (void)callViewController:(CallViewController *)controller didAppendAssistantText:(NSString *)assistantText {
    (void)controller;
    [self appendMessage:assistantText role:ChatMessageRoleAssistant];
}

- (void)callViewControllerDidClose:(CallViewController *)controller {
    (void)controller;
    self.isCallPresented = NO;
    [self appendMessage:@"通话已关闭，已回到 IM 聊天窗口。" role:ChatMessageRoleSystem];
    if (self.wakeAuthorized) {
        [self startWakeListening];
    }
}

@end
