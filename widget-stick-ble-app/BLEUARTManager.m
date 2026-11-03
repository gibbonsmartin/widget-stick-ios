//
//  BLEUARTManager.m
//  widget-stick-ble-app
//

#import "BLEUARTManager.h"

NSString * const kHM10ServiceUUIDString = @"FFE0";
NSString * const kHM10CharacteristicUUIDString = @"FFE1";

@interface BLEUARTManager () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray<CBPeripheral *> *peripheralsList;
@property (nonatomic, strong, readwrite, nullable) CBPeripheral *connectedPeripheral;
@property (nonatomic, strong, nullable) CBCharacteristic *uartCharacteristic;
@property (nonatomic, strong) NSMutableData *rxBuffer;
@property (nonatomic, assign) BOOL shouldScanWhenPoweredOn;

@end

@implementation BLEUARTManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _peripheralsList = [NSMutableArray array];
        _rxBuffer = [NSMutableData data];
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
    }
    return self;
}

- (NSArray<CBPeripheral *> *)discoveredPeripherals {
    return [self.peripheralsList copy];
}

- (BOOL)isReady {
    return (self.connectedPeripheral.state == CBPeripheralStateConnected && self.uartCharacteristic != nil);
}

#pragma mark - Public Scanning & Connection

- (void)startScanning {
    [self.peripheralsList removeAllObjects];
    if (self.centralManager.state == CBManagerStatePoweredOn) {
        self.shouldScanWhenPoweredOn = NO;
        [self.centralManager scanForPeripheralsWithServices:nil
                                                    options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}];
    } else {
        self.shouldScanWhenPoweredOn = YES;
    }
}

- (void)stopScanning {
    self.shouldScanWhenPoweredOn = NO;
    if (self.centralManager.state == CBManagerStatePoweredOn && self.centralManager.isScanning) {
        [self.centralManager stopScan];
    }
}

- (void)connectPeripheral:(CBPeripheral *)peripheral {
    [self stopScanning];
    if (self.connectedPeripheral && self.connectedPeripheral != peripheral) {
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
    self.connectedPeripheral = peripheral;
    self.connectedPeripheral.delegate = self;
    [self.centralManager connectPeripheral:peripheral options:nil];
}

- (void)disconnect {
    if (self.connectedPeripheral) {
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
}

#pragma mark - BLE UART Read & Write

- (BOOL)readData {
    if (!self.isReady) {
        return NO;
    }
    if (self.uartCharacteristic.properties & CBCharacteristicPropertyRead) {
        [self.connectedPeripheral readValueForCharacteristic:self.uartCharacteristic];
        return YES;
    }
    return NO;
}

- (BOOL)writeData:(NSData *)data {
    if (!self.isReady || data.length == 0) {
        return NO;
    }

    CBCharacteristicWriteType writeType = CBCharacteristicWriteWithResponse;
    if (self.uartCharacteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) {
        writeType = CBCharacteristicWriteWithoutResponse;
    } else if (self.uartCharacteristic.properties & CBCharacteristicPropertyWrite) {
        writeType = CBCharacteristicWriteWithResponse;
    } else {
        return NO;
    }

    [self.connectedPeripheral writeValue:data forCharacteristic:self.uartCharacteristic type:writeType];
    return YES;
}

- (BOOL)writeString:(NSString *)string {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return NO;
    }
    return [self writeData:data];
}

- (nullable NSData *)consumeBufferedRxData {
    @synchronized (self.rxBuffer) {
        if (self.rxBuffer.length == 0) {
            return nil;
        }
        NSData *data = [self.rxBuffer copy];
        [self.rxBuffer setLength:0];
        return data;
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn && self.shouldScanWhenPoweredOn) {
        self.shouldScanWhenPoweredOn = NO;
        [self startScanning];
    }

    if ([self.delegate respondsToSelector:@selector(bleUARTManager:didUpdateState:)]) {
        [self.delegate bleUARTManager:self didUpdateState:central.state];
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *,id> *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    if (![self.peripheralsList containsObject:peripheral]) {
        [self.peripheralsList addObject:peripheral];
    }

    if ([self.delegate respondsToSelector:@selector(bleUARTManager:didDiscoverPeripheral:advertisementData:RSSI:)]) {
        [self.delegate bleUARTManager:self didDiscoverPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    self.connectedPeripheral = peripheral;
    peripheral.delegate = self;
    CBUUID *hm10ServiceUUID = [CBUUID UUIDWithString:kHM10ServiceUUIDString];
    [peripheral discoverServices:@[hm10ServiceUUID]];

    if ([self.delegate respondsToSelector:@selector(bleUARTManager:didConnectPeripheral:)]) {
        [self.delegate bleUARTManager:self didConnectPeripheral:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(nullable NSError *)error {
    if (self.connectedPeripheral == peripheral) {
        self.connectedPeripheral = nil;
        self.uartCharacteristic = nil;
    }
    if ([self.delegate respondsToSelector:@selector(bleUARTManager:didDisconnectPeripheral:error:)]) {
        [self.delegate bleUARTManager:self didDisconnectPeripheral:peripheral error:error];
    }
}

- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(nullable NSError *)error {
    if (self.connectedPeripheral == peripheral) {
        self.connectedPeripheral = nil;
        self.uartCharacteristic = nil;
    }
    if ([self.delegate respondsToSelector:@selector(bleUARTManager:didDisconnectPeripheral:error:)]) {
        [self.delegate bleUARTManager:self didDisconnectPeripheral:peripheral error:error];
    }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    if (error) {
        return;
    }

    CBUUID *hm10CharUUID = [CBUUID UUIDWithString:kHM10CharacteristicUUIDString];
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:kHM10ServiceUUIDString]]) {
            [peripheral discoverCharacteristics:@[hm10CharUUID] forService:service];
        } else {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(nullable NSError *)error {
    if (error) {
        return;
    }

    CBUUID *hm10CharUUID = [CBUUID UUIDWithString:kHM10CharacteristicUUIDString];
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:hm10CharUUID]) {
            self.uartCharacteristic = characteristic;
            if (characteristic.properties & (CBCharacteristicPropertyNotify | CBCharacteristicPropertyIndicate)) {
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
            break;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(nullable NSError *)error {
    if (error || characteristic.value.length == 0) {
        return;
    }

    NSData *data = [characteristic.value copy];
    @synchronized (self.rxBuffer) {
        [self.rxBuffer appendData:data];
    }

    if ([self.delegate respondsToSelector:@selector(bleUARTManager:didReceiveData:)]) {
        [self.delegate bleUARTManager:self didReceiveData:data];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(nullable NSError *)error {
    if ([self.delegate respondsToSelector:@selector(bleUARTManager:didWriteDataWithError:)]) {
        [self.delegate bleUARTManager:self didWriteDataWithError:error];
    }
}

@end
