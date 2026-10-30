//
//  ViewController.m
//  widget-stick-client
//

#import "ViewController.h"
#import "AppDelegate.h"
#include "c_schedule.h"

@interface ViewController () <UITextFieldDelegate>

@property (nonatomic, strong, readwrite) UITextField *inputField1;
@property (nonatomic, strong, readwrite) UITextField *inputField2;
@property (nonatomic, strong, readwrite) UIButton *actionButton;
@property (nonatomic, strong, readwrite) UITextField *outputTextField;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self setupUI];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleScheduleUpdate:)
                                                 name:kScheduleDidUpdateNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupUI {
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"widget-stick-client";
    titleLabel.font = [UIFont boldSystemFontOfSize:22.0];
    titleLabel.textAlignment = NSTextAlignmentCenter;

    self.inputField1 = [[UITextField alloc] init];
    self.inputField1.placeholder = @"Input 1 (e.g. Task / Command)";
    self.inputField1.borderStyle = UITextBorderStyleRoundedRect;
    self.inputField1.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.inputField1.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.inputField1.returnKeyType = UIReturnKeyNext;
    self.inputField1.delegate = self;

    self.inputField2 = [[UITextField alloc] init];
    self.inputField2.placeholder = @"Input 2 (e.g. Schedule / Interval)";
    self.inputField2.borderStyle = UITextBorderStyleRoundedRect;
    self.inputField2.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.inputField2.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.inputField2.returnKeyType = UIReturnKeyDone;
    self.inputField2.delegate = self;

    UIButtonConfiguration *buttonConfig = [UIButtonConfiguration filledButtonConfiguration];
    buttonConfig.title = @"Run C Schedule";
    buttonConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    self.actionButton = [UIButton buttonWithConfiguration:buttonConfig primaryAction:nil];
    [self.actionButton addTarget:self
                          action:@selector(didTapActionButton:)
                forControlEvents:UIControlEventTouchUpInside];

    self.outputTextField = [[UITextField alloc] init];
    self.outputTextField.placeholder = @"Schedule Output";
    self.outputTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.outputTextField.enabled = NO;
    self.outputTextField.textColor = [UIColor labelColor];
    self.outputTextField.font = [UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular];

    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        titleLabel,
        self.inputField1,
        self.inputField2,
        self.actionButton,
        self.outputTextField
    ]];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 16.0;
    stackView.alignment = UIStackViewAlignmentFill;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:stackView];

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stackView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:24.0],
        [stackView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-24.0],
        [stackView.centerYAnchor constraintEqualToAnchor:safeArea.centerYAnchor],
        [self.inputField1.heightAnchor constraintEqualToConstant:44.0],
        [self.inputField2.heightAnchor constraintEqualToConstant:44.0],
        [self.actionButton.heightAnchor constraintEqualToConstant:48.0],
        [self.outputTextField.heightAnchor constraintEqualToConstant:44.0]
    ]];
}

- (void)didTapActionButton:(id)sender {
    [self.view endEditing:YES];

    NSString *input1 = self.inputField1.text ?: @"";
    NSString *input2 = self.inputField2.text ?: @"";

    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    if ([appDelegate respondsToSelector:@selector(beginBackgroundScheduleExecutionWithInput1:input2:)]) {
        [appDelegate beginBackgroundScheduleExecutionWithInput1:input1 input2:input2];
    } else {
        char buffer[512];
        if (c_schedule_execute([input1 UTF8String], [input2 UTF8String], buffer, sizeof(buffer)) == 0) {
            self.outputTextField.text = [NSString stringWithUTF8String:buffer];
        }
    }
}

- (void)handleScheduleUpdate:(NSNotification *)notification {
    NSString *output = notification.userInfo[@"output"];
    if (output) {
        self.outputTextField.text = output;
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.inputField1) {
        [self.inputField2 becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
        [self didTapActionButton:nil];
    }
    return YES;
}

@end
