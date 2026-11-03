//
//  ViewController.m
//  widget-stick-ble-app
//

#import "ViewController.h"
#import "BLEUARTManager.h"
#include "tcp_client.h"

static const NSTimeInterval kPeriodicTimerInterval = 2.0;

@interface ViewController () <UITextFieldDelegate, BLEUARTManagerDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong, readwrite) UITextField *inputField1;
@property (nonatomic, strong, readwrite) UITextField *inputField2;
@property (nonatomic, strong, readwrite) UIButton *actionButton;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong) BLEUARTManager *bleManager;
@property (nonatomic, strong, nullable) NSTimer *periodicTimer;
@property (nonatomic, weak, nullable) UITableViewController *bleScanTableViewController;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.bleManager = [[BLEUARTManager alloc] init];
    self.bleManager.delegate = self;

    [self setupUI];
    [self startPeriodicTimer];
}

- (void)dealloc {
    [self.periodicTimer invalidate];
    self.periodicTimer = nil;
}

#pragma mark - UI Setup

- (void)setupUI {
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"BLE UART to TCP Client";
    titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
    titleLabel.textAlignment = NSTextAlignmentCenter;

    self.inputField1 = [[UITextField alloc] init];
    self.inputField1.placeholder = @"TCP Host (e.g. 127.0.0.1)";
    self.inputField1.text = @"127.0.0.1";
    self.inputField1.borderStyle = UITextBorderStyleRoundedRect;
    self.inputField1.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.inputField1.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.inputField1.autocorrectionType = UITextAutocorrectionTypeNo;
    self.inputField1.returnKeyType = UIReturnKeyNext;
    self.inputField1.delegate = self;

    self.inputField2 = [[UITextField alloc] init];
    self.inputField2.placeholder = @"TCP Port / BLE Command (e.g. 8080)";
    self.inputField2.text = @"8080";
    self.inputField2.borderStyle = UITextBorderStyleRoundedRect;
    self.inputField2.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.inputField2.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.inputField2.autocorrectionType = UITextAutocorrectionTypeNo;
    self.inputField2.returnKeyType = UIReturnKeyDone;
    self.inputField2.delegate = self;

    UIButtonConfiguration *buttonConfig = [UIButtonConfiguration filledButtonConfiguration];
    buttonConfig.title = @"Connect BLE";
    buttonConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    self.actionButton = [UIButton buttonWithConfiguration:buttonConfig primaryAction:nil];
    [self.actionButton addTarget:self
                          action:@selector(didTapActionButton:)
                forControlEvents:UIControlEventTouchUpInside];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"Status: Disconnected";
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;

    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        titleLabel,
        self.inputField1,
        self.inputField2,
        self.actionButton,
        self.statusLabel
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
        [self.actionButton.heightAnchor constraintEqualToConstant:48.0]
    ]];
}

#pragma mark - Button & BLE Connect Dialogue

- (void)didTapActionButton:(id)sender {
    [self.view endEditing:YES];
    [self presentBLEConnectDialogue];
}

- (void)presentBLEConnectDialogue {
    [self.bleManager startScanning];

    UITableViewController *tableVC = [[UITableViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    tableVC.title = @"Select BLE UART Device (FFE0)";
    tableVC.tableView.dataSource = self;
    tableVC.tableView.delegate = self;

    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                target:self
                                                                                action:@selector(dismissBLEConnectDialogue)];
    tableVC.navigationItem.leftBarButtonItem = cancelItem;

    if (self.bleManager.connectedPeripheral) {
        UIBarButtonItem *disconnectItem = [[UIBarButtonItem alloc] initWithTitle:@"Disconnect"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(disconnectBLEFromDialogue)];
        disconnectItem.tintColor = [UIColor systemRedColor];
        tableVC.navigationItem.rightBarButtonItem = disconnectItem;
    }

    self.bleScanTableViewController = tableVC;

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:tableVC];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)dismissBLEConnectDialogue {
    [self.bleManager stopScanning];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)disconnectBLEFromDialogue {
    [self.bleManager disconnect];
    [self dismissBLEConnectDialogue];
}

#pragma mark - Periodic Timer (Poll BLE UART -> Forward to TCP Server)

- (void)startPeriodicTimer {
    [self.periodicTimer invalidate];
    self.periodicTimer = [NSTimer scheduledTimerWithTimeInterval:kPeriodicTimerInterval
                                                          target:self
                                                        selector:@selector(handlePeriodicTimerTick:)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)handlePeriodicTimerTick:(NSTimer *)timer {
    // Poll/read BLE UART characteristic if connected
    if (self.bleManager.isReady) {
        [self.bleManager readData];
    }

    // Consume any received BLE UART data and forward it to the TCP server
    NSData *bleRxData = [self.bleManager consumeBufferedRxData];
    if (bleRxData.length > 0) {
        [self forwardDataToTCPServer:bleRxData];
    }
}

- (void)forwardDataToTCPServer:(NSData *)payload {
    NSString *host = self.inputField1.text.length > 0 ? self.inputField1.text : @"127.0.0.1";
    NSString *port = self.inputField2.text.length > 0 ? self.inputField2.text : @"8080";
    NSData *payloadCopy = [payload copy];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char rxBuffer[1024];
        int bytesReceived = tcp_client_transfer([host UTF8String],
                                                [port UTF8String],
                                                (const char *)payloadCopy.bytes,
                                                payloadCopy.length,
                                                rxBuffer,
                                                sizeof(rxBuffer));

        NSData *tcpResponseData = nil;
        NSString *statusText = nil;
        if (bytesReceived >= 0) {
            if (bytesReceived > 0) {
                tcpResponseData = [NSData dataWithBytes:rxBuffer length:(NSUInteger)bytesReceived];
            }
            NSString *rxString = [[NSString alloc] initWithBytes:rxBuffer
                                                          length:(NSUInteger)(bytesReceived > 0 ? bytesReceived : 0)
                                                        encoding:NSUTF8StringEncoding] ?: @"";
            statusText = [NSString stringWithFormat:@"Status: Forwarded %lu B -> TCP RX (%d B): %@",
                          (unsigned long)payloadCopy.length, bytesReceived, rxString];
        } else {
            statusText = [NSString stringWithFormat:@"Status: TCP connect/send failed (%@:%@)", host, port];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf.statusLabel.text = statusText;
            // Write TCP server response back to BLE UART if present
            if (tcpResponseData.length > 0 && strongSelf.bleManager.isReady) {
                [strongSelf.bleManager writeData:tcpResponseData];
            }
        });
    });
}

#pragma mark - BLEUARTManagerDelegate

- (void)bleUARTManager:(BLEUARTManager *)manager didUpdateState:(CBManagerState)state {
    if (state != CBManagerStatePoweredOn) {
        self.statusLabel.text = [NSString stringWithFormat:@"Status: Bluetooth state %ld", (long)state];
    }
}

- (void)bleUARTManager:(BLEUARTManager *)manager
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *,id> *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    [self.bleScanTableViewController.tableView reloadData];
}

- (void)bleUARTManager:(BLEUARTManager *)manager didConnectPeripheral:(CBPeripheral *)peripheral {
    NSString *name = peripheral.name.length > 0 ? peripheral.name : peripheral.identifier.UUIDString;
    self.statusLabel.text = [NSString stringWithFormat:@"Status: Connected to %@", name];

    UIButtonConfiguration *config = self.actionButton.configuration;
    config.title = [NSString stringWithFormat:@"Connected: %@", name];
    self.actionButton.configuration = config;
}

- (void)bleUARTManager:(BLEUARTManager *)manager
didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    self.statusLabel.text = @"Status: Disconnected";

    UIButtonConfiguration *config = self.actionButton.configuration;
    config.title = @"Connect BLE";
    self.actionButton.configuration = config;
}

- (void)bleUARTManager:(BLEUARTManager *)manager didReceiveData:(NSData *)data {
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!str) {
        str = [data description];
    }
    self.statusLabel.text = [NSString stringWithFormat:@"Status: BLE RX (%lu B): %@", (unsigned long)data.length, str];
}

#pragma mark - UITableViewDataSource & UITableViewDelegate (BLE Connect Dialogue)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count = self.bleManager.discoveredPeripherals.count;
    return count > 0 ? count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"BLEDeviceCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    NSArray<CBPeripheral *> *peripherals = self.bleManager.discoveredPeripherals;
    if (peripherals.count == 0) {
        cell.textLabel.text = @"Scanning for BLE devices...";
        cell.detailTextLabel.text = @"Service FFE0 / Characteristic FFE1";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        CBPeripheral *peripheral = peripherals[indexPath.row];
        cell.textLabel.text = peripheral.name.length > 0 ? peripheral.name : @"Unnamed BLE Device";
        cell.detailTextLabel.text = peripheral.identifier.UUIDString;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = (peripheral == self.bleManager.connectedPeripheral)
            ? UITableViewCellAccessoryCheckmark
            : UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray<CBPeripheral *> *peripherals = self.bleManager.discoveredPeripherals;
    if (indexPath.row < peripherals.count) {
        CBPeripheral *selected = peripherals[indexPath.row];
        [self.bleManager connectPeripheral:selected];
        [self dismissBLEConnectDialogue];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.inputField1) {
        [self.inputField2 becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

@end
