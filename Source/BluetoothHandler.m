//
//  BluetoothHandler.m
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-03-30.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "BluetoothHandler.h"
#import "Parameters.h"

@interface PeripheralInfo : NSObject
@property(strong, nonatomic)CBPeripheral *peripheral;
@property (strong, nonatomic) CBCharacteristic *readCharacteristic;
@property (strong, nonatomic) CBCharacteristic *writeCharacteristic;
@end

@implementation PeripheralInfo
@synthesize peripheral;
@synthesize readCharacteristic;
@synthesize writeCharacteristic;
@end



@interface BluetoothHandler()
{
    BOOL isHost;
    //MCPeerID *hostPeerID;
}

@property (nonatomic, strong) dispatch_queue_t concurrentChatDelegateQueue;

// server properties
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSMutableDictionary *discoveredPeripherals; // key:name value:PeripheralInfo
@end

@implementation BluetoothHandler

// begin implement NetworkConnectionProtocol
-(void) setupNetwork
{
    self.concurrentChatDelegateQueue = dispatch_queue_create("com.nc.networkteset.cb",DISPATCH_QUEUE_CONCURRENT);
}

-(void) startHost
{
    isHost = YES;
    self.discoveredPeripherals = [[NSMutableDictionary alloc]init];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.concurrentChatDelegateQueue];
}

-(void) startClient
{
    isHost = NO;
    CCLOG(@"function 'startClient' is not implemented by current network type!!!");
}

-(void)sendDataToAll : (NSData*)data reliableFlag:(BOOL)isReliable
{
    CCLOG(@"function 'sendDataToAll' is not implemented by current network type!!!");
}

-(void)sendDataToHost : (NSData*)data reliableFlag:(BOOL)isReliable
{
    CCLOG(@"function 'sendDataToHost' is not implemented by current network type!!!");
}

-(void)sendData : (NSData*)data toPeer:(NSString*)peerName reliableFlag:(BOOL)isReliable
{
    CCLOG(@"function 'sendData toPeer' is not implemented by current network type!!!");
}

-(int) connectionCount
{
    if (isHost) {
        return [self.discoveredPeripherals count];
    }
    return 0;
}

-(void) stopSearch
{
    [self.centralManager stopScan];
}

-(void) stopAdvertise
{
    CCLOG(@"function 'stopAdvertise' is not implemented by current network type!!!");
}

-(void) disconnect
{
    if (isHost) {
        NSEnumerator *enmuerator = [self.discoveredPeripherals objectEnumerator];
        
        for (PeripheralInfo *info in enmuerator) {
            if (info.peripheral !=nil)
            {
                for (CBService *service in info.peripheral.services)
                {
                    if (service.characteristics != nil)
                    {
                        for (CBCharacteristic *characteristic in service.characteristics) {
                            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID]])
                            {
                                if (characteristic.isNotifying) {
                                    [info.peripheral setNotifyValue:NO forCharacteristic:characteristic];
                                }
                            }
                        }
                    }
                }
                [self.centralManager cancelPeripheralConnection:info.peripheral];
            }
        }
    }
}
// end implement NetworkConnectionProtocol

// begin CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn) {
        CCLOG(@"Bluetooth is OFF !!!");
        NSDictionary *userInfo = @{ @"error": @"Bluetooth Off"};
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_DID_NOT_START_NOTIFICATION
                                                                object:nil
                                                              userInfo:userInfo];
        });
        return;
    }
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]  options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}] ;
        CCLOG(@"Bluetooth server scanning started");
    }
}

- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    if (self.discoveredPeripherals[peripheral.name] == nil) {
        
        NSDictionary *userInfo = @{ @"peerName": [peripheral name]};
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_DID_FOUND_CLIENT_NOTIFICATION
                                                                object:nil
                                                              userInfo:userInfo];
        });
        
        CCLOG(@"Connecting to peripheral %@", peripheral);
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self broadcastConnectionInfo:[NSString stringWithFormat:@"\nfalied to connect to %@ error : %@", [peripheral name], error]];

    [self.centralManager cancelPeripheralConnection:peripheral];
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    CCLOG(@"Connected to %@", peripheral.name);
    
    if (self.discoveredPeripherals[peripheral.name] == nil) {
        PeripheralInfo *info = [[PeripheralInfo alloc]init];
        info.peripheral = peripheral;
        info.readCharacteristic = nil;
        info.writeCharacteristic = nil;
        self.discoveredPeripherals[peripheral.name] = info;
        peripheral.delegate = self;
        
        CCLOG(@"Trying to find transfer service in %@", peripheral.name);
        [self broadcastConnectionInfo:[NSString stringWithFormat:@"\nconnected with %@\nfinding transfer service in %@", [peripheral name], [peripheral name]]];
        
        [peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self broadcastConnectionInfo:nil];
}
// end CBCentralManagerDelegate

-(void)broadcastConnectionInfo:(NSString*)message
{
    NSDictionary *userInfo = @{ @"connectionInfo": message};
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:CONNECTION_STATE_CHANGED_NOTIFICATION
                                                            object:nil
                                                          userInfo:userInfo];
    });
}

// begin CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        [self broadcastConnectionInfo:[NSString stringWithFormat:@"\nfalied to find transfer service in %@ error : %@", [peripheral name], error]];
        [self.discoveredPeripherals removeObjectForKey:[peripheral name]];
        [self.centralManager cancelPeripheralConnection:peripheral];
        return;
    }
    
    CCLOG(@"transfer service found in %@", peripheral.name);
    [self broadcastConnectionInfo:[NSString stringWithFormat:@"\ntransfer service found in %@\nfinding transfer characteristics in %@", [peripheral name], [peripheral name]]];
    
    for (CBService *service in peripheral.services)
    {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID], [CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID]] forService:service];
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
        [self broadcastConnectionInfo:[NSString stringWithFormat:@"\nfalied to find transfer characteristics in %@ error : %@", [peripheral name], error]];
        [self.discoveredPeripherals removeObjectForKey:[peripheral name]];
        [self.centralManager cancelPeripheralConnection:peripheral];
        return;
    }
    
    [self broadcastConnectionInfo:[NSString stringWithFormat:@"\ntransfer characteristics found in %@",[peripheral name]]];
    
    PeripheralInfo *info = self.discoveredPeripherals[peripheral.name];
    
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID]])
        {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            info.readCharacteristic = characteristic;
        }
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID]])
        {
            info.writeCharacteristic = characteristic;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CLIENT_CONNECTION_DONE_NOTIFICATION
                                                            object:nil
                                                          userInfo:nil];
    });

}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    CFTimeInterval t = CACurrentMediaTime() * 1000;
    NSNumber *time = [NSNumber numberWithDouble:t];
    
    if (error)
    {
        CCLOG(@"peripheral update value failed for characteristic %@ with error : %@", characteristic, error);
        return;
    }
    
    PeripheralInfo *info = self.discoveredPeripherals[peripheral.name];
    
    if (![characteristic isEqual:info.readCharacteristic]) {
        return;
    }
   
    NSDictionary *userInfo = @{ @"data": characteristic.value,
                                @"peerName": [peripheral name],
                                @"time": time};
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:RECEIVED_DATA_NOTIFICATION
                                                            object:nil
                                                          userInfo:userInfo];
    });
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID]]) {
        return;
    }
    
    if (characteristic.isNotifying) {
        CCLOG(@"Notification began on %@", characteristic);
    } else {
        [self broadcastConnectionInfo:nil];
        [self.discoveredPeripherals removeObjectForKey:peripheral.name];
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    
    
    if (error)
    {
        NSLog(@"Central write Error : %@", error);
        return;
    }
}
// end CBPeripheralDelegate



@end
