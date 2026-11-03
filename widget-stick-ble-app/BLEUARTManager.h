//
//  BLEUARTManager.h
//  widget-stick-ble-app
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kHM10ServiceUUIDString;
extern NSString * const kHM10CharacteristicUUIDString;

@class BLEUARTManager;

@protocol BLEUARTManagerDelegate <NSObject>
@optional
- (void)bleUARTManager:(BLEUARTManager *)manager didUpdateState:(CBManagerState)state;
- (void)bleUARTManager:(BLEUARTManager *)manager didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI;
- (void)bleUARTManager:(BLEUARTManager *)manager didConnectPeripheral:(CBPeripheral *)peripheral;
- (void)bleUARTManager:(BLEUARTManager *)manager didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error;
- (void)bleUARTManager:(BLEUARTManager *)manager didReceiveData:(NSData *)data;
- (void)bleUARTManager:(BLEUARTManager *)manager didWriteDataWithError:(nullable NSError *)error;
@end

@interface BLEUARTManager : NSObject

@property (nonatomic, weak, nullable) id<BLEUARTManagerDelegate> delegate;
@property (nonatomic, strong, readonly) NSArray<CBPeripheral *> *discoveredPeripherals;
@property (nonatomic, strong, readonly, nullable) CBPeripheral *connectedPeripheral;
@property (nonatomic, assign, readonly, getter=isReady) BOOL ready;

/// Starts scanning for BLE UART peripherals (HM-10 / TI CC254x FFE0 service and general peripherals).
- (void)startScanning;

/// Stops an active BLE scan.
- (void)stopScanning;

/// Connects to the selected BLE peripheral.
- (void)connectPeripheral:(CBPeripheral *)peripheral;

/// Disconnects from the currently connected BLE peripheral.
- (void)disconnect;

/// Triggers an explicit BLE GATT read on the UART characteristic (FFE1).
- (BOOL)readData;

/// Writes raw data to the BLE UART characteristic (FFE1).
- (BOOL)writeData:(NSData *)data;

/// Writes a UTF-8 string to the BLE UART characteristic (FFE1).
- (BOOL)writeString:(NSString *)string;

/// Dequeues and returns all buffered incoming UART data received since the last call.
- (nullable NSData *)consumeBufferedRxData;

@end

NS_ASSUME_NONNULL_END
