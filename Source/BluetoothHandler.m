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
@property(strong, nonatomic)NSString *name;
@end

@implementation PeripheralInfo
@synthesize peripheral;
@synthesize readCharacteristic;
@synthesize writeCharacteristic;
@synthesize name;
@end



@interface BluetoothHandler()
{
    BOOL isHost;
    //MCPeerID *hostPeerID;
    
    // client
    BOOL isConnectedToCentral;
    NSMutableArray *dataToSend;
}

@property (nonatomic, strong) dispatch_queue_t concurrentChatDelegateQueue;

// server properties
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSMutableDictionary<NSString*, PeripheralInfo*> *discoveredPeripherals; // key:UUIDString value:PeripheralInfo

// client properties
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *sendCharacteristic;
@property (strong, nonatomic) CBMutableCharacteristic *receiveCharacteristic;

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
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.concurrentChatDelegateQueue];
}

-(void)sendDataToAll : (NSData*)data reliableFlag:(BOOL)isReliable
{
    if (isHost) {
        NSEnumerator *enmuerator = [self.discoveredPeripherals objectEnumerator];
        for (PeripheralInfo *info in enmuerator) {
            [info.peripheral writeValue:data forCharacteristic:info.writeCharacteristic type:CBCharacteristicWriteWithResponse];
        }
    }
}

-(void)sendDataToHost : (NSData*)data reliableFlag:(BOOL)isReliable
{
    if (!isHost) {
        BOOL didSent = [self.peripheralManager updateValue:data forCharacteristic:self.sendCharacteristic onSubscribedCentrals:nil];
        
        if (dataToSend == nil) {
            dataToSend = [[NSMutableArray alloc] init];
        }
        if (!didSent) {
            CCLOG(@"message didn't send, added to dataToSend queue.");
            if (![dataToSend containsObject:data]) {
                [dataToSend addObject:data];
            }
        } else {
            [dataToSend removeObject:data];
        }
    }
}

-(void)sendData : (NSData*)data toPeer:(id)peerName reliableFlag:(BOOL)isReliable
{
    PeripheralInfo *info = self.discoveredPeripherals[(NSString*)peerName];
    if (info) {
        [info.peripheral writeValue:data forCharacteristic:info.writeCharacteristic type:CBCharacteristicWriteWithResponse];
    }
}

-(int) connectionCount
{
    if (isHost) {
        return [self.discoveredPeripherals count];
    } else {
        if (isConnectedToCentral) {
            return 1;
        } else {
            return 0;
        }
    }
}

-(void) stopSearch
{
    CCLOG(@"Bluetooth server stop search");
    [self.centralManager stopScan];
}

-(void) stopAdvertise
{
    CCLOG(@"Bluetooth client stop advertise");

    [self.peripheralManager stopAdvertising];
}

-(void) disconnect
{
    if (isHost) {
        [self stopSearch];
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
    } else {
        [self stopAdvertise];
    }
}
// end implement NetworkConnectionProtocol

-(void)broadcastConnectionInfo:(NSString*)message
{
    NSDictionary *userInfo = @{ @"connectionInfo": message};
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:CONNECTION_STATE_CHANGED_NOTIFICATION
                                                            object:nil
                                                          userInfo:userInfo];
    });
}

/***********************************************************************/
/*                          SERVER FUNCTIONS                           */
/***********************************************************************/

// begin CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn) {
        CCLOG(@"Bluetooth is OFF !!!");
        NSDictionary *userInfo = @{ @"error": @"Bluetooth Off"};
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CLIENT_DID_NOT_START_NOTIFICATION
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
    if (![advertisementData[CBAdvertisementDataServiceUUIDsKey] containsObject:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] || [advertisementData count] < 3) {
        return;
    }
    NSString* name = advertisementData[CBAdvertisementDataLocalNameKey];
    
    if (self.discoveredPeripherals[peripheral.identifier.UUIDString] == nil) {
        CCLOG(@"Discovered %@ at %@", peripheral.name, RSSI);

        PeripheralInfo *info = [[PeripheralInfo alloc]init];
        info.peripheral = peripheral;
        info.readCharacteristic = nil;
        info.writeCharacteristic = nil;
        info.name = name;
        self.discoveredPeripherals[peripheral.identifier.UUIDString] = info;
        peripheral.delegate = self;
        
        NSDictionary *userInfo = @{ @"peerName": name};
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_DID_FOUND_CLIENT_NOTIFICATION
                                                                object:nil
                                                              userInfo:userInfo];
        });
        
        CCLOG(@"Connecting to peripheral name = %@ id = %@", name, peripheral.identifier.UUIDString);
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    PeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    if (info) {
        [self broadcastConnectionInfo:[NSString stringWithFormat:@"\nfalied to connect to %@ error : %@", info.name, error]];
        
        [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
    } else {
        // shouldn't be here
        CCLOG(@"error!!!  cannot find peripheral in discoveredPeripherals");
    }
    
    [self.centralManager cancelPeripheralConnection:peripheral];
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    PeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    if (!info) {
        // shouldn't be here
        CCLOG(@"error!!!  cannot find peripheral in discoveredPeripherals");
        return;
    }
    
    CCLOG(@"Connected to %@", info.name);
    CCLOG(@"Trying to find transfer service in %@", info.name);
    [self broadcastConnectionInfo:[NSString stringWithFormat:@"\nconnected with %@\nfinding transfer service in %@", info.name, info.name]];
    [peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    CCLOG(@"didDisconnectPeripheral");
    [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
    [self broadcastConnectionInfo:@""];
}
// end CBCentralManagerDelegate

// begin CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    PeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    if (!info) {
        // shouldn't be here
        CCLOG(@"error!!!  cannot find peripheral in discoveredPeripherals");
        return;
    }
    if (error)
    {
        [self broadcastConnectionInfo:[NSString stringWithFormat:@"\nfalied to find transfer service in %@ error : %@", info.name, error]];
        [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
        [self.centralManager cancelPeripheralConnection:peripheral];
        return;
    }
    
    CCLOG(@"transfer service found in %@", info.name);
    [self broadcastConnectionInfo:[NSString stringWithFormat:@"\ntransfer service found in %@\nfinding transfer characteristics in %@", info.name, info.name]];
    
    for (CBService *service in peripheral.services)
    {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID], [CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID]] forService:service];
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    PeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    if (!info) {
        // shouldn't be here
        CCLOG(@"error!!!  cannot find peripheral in discoveredPeripherals");
        return;
    }
    if (error) {
        [self broadcastConnectionInfo:[NSString stringWithFormat:@"\nfalied to find transfer characteristics in %@ error : %@", info.name, error]];
        [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
        [self.centralManager cancelPeripheralConnection:peripheral];
        return;
    }
 
    BOOL isReadCharFound = NO;
    BOOL isWriteCharFoud = NO;
    
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID]])
        {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            info.readCharacteristic = characteristic;
            isReadCharFound = YES;
        }
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID]])
        {
            info.writeCharacteristic = characteristic;
            isWriteCharFoud = YES;
        }
    }
#if __CC_PLATFORM_IOS
    CCLOG(@"peripheral maxResponse : %lu , maxNoResponse : %lu", (unsigned long)[peripheral maximumWriteValueLengthForType: CBCharacteristicWriteWithResponse], (unsigned long)[peripheral maximumWriteValueLengthForType: CBCharacteristicWriteWithoutResponse]);
#endif
    
    NSString *msg = [NSString stringWithFormat:@"\nread characteristics found in %@ : %@ with properties : %lu\nwrite characteristics found in %@ : %@ with properties : %lu",info.name, isReadCharFound ? @"YES" : @"NO", (unsigned long)info.readCharacteristic.properties, info.name, isWriteCharFoud ? @"YES" : @"NO", (unsigned long)info.writeCharacteristic.properties];
    CCLOG(@"%@", msg);
    [self broadcastConnectionInfo:msg];
    
    if (isReadCharFound && isWriteCharFoud) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CLIENT_CONNECTION_DONE_NOTIFICATION
                                                                object:nil
                                                              userInfo:nil];
        });
    } else {
        [self broadcastConnectionInfo:[NSString stringWithFormat:@"\nfalied to find transfer characteristics in %@ error : %@", info.name, error]];
        [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
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
    
    PeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    
    if (![characteristic isEqual:info.readCharacteristic]) {
        return;
    }
   
    NSDictionary *userInfo = @{ @"data": characteristic.value,
                                @"peerName": peripheral.identifier.UUIDString,
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
    
    if (error != nil) {
        CCLOG(@"set notification falied : %@", error);
        [self broadcastConnectionInfo:@""];
        [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    PeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    CCLOG(@"didWriteValueForCharacteristic to %@", info.name);
    
    if (error)
    {
        CCLOG(@"Central write Error : %@", error);
        return;
    }
}
// end CBPeripheralDelegate

/***********************************************************************/
/*                          CLIENT FUNCTIONS                           */
/***********************************************************************/

// begin CBPeripheralManagerDelegate
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        CCLOG(@"Bluetooth is OFF !!!");
        NSDictionary *userInfo = @{ @"error": @"Bluetooth Off"};
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CLIENT_DID_NOT_START_NOTIFICATION
                                                                object:nil
                                                              userInfo:userInfo];
        });
        return;
    }
    
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        self.sendCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID] properties:CBCharacteristicPropertyNotify | CBCharacteristicPropertyRead value:nil permissions:CBAttributePermissionsReadable];
        
        self.receiveCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID] properties:CBCharacteristicPropertyWrite value:nil permissions:CBAttributePermissionsWriteable];
        
        CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID] primary:YES];
        
        transferService.characteristics = @[self.sendCharacteristic, self.receiveCharacteristic];
        
        [self.peripheralManager addService:transferService];
        
        isConnectedToCentral = NO;
#if __CC_PLATFORM_IOS
        NSString *name = [UIDevice currentDevice].name;
#elif __CC_PLATFORM_MAC
        NSString *name = [[NSHost currentHost] localizedName];
#endif        
        [self.peripheralManager startAdvertising:@{CBAdvertisementDataLocalNameKey:name,CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]}];
        CCLOG(@"peripheralManager startAdvertising...");
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    CCLOG(@"didSubscribeToCharacteristic central.maximumUpdateValueLength = %lu" , (unsigned long)central.maximumUpdateValueLength);
    if ([self.sendCharacteristic isEqual:characteristic]) {
        NSString *string = @"\nserver subscribed send characteristic";
        [self broadcastConnectionInfo:string];
        
        isConnectedToCentral = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CLIENT_CONNECTION_DONE_NOTIFICATION
                                                                object:nil
                                                              userInfo:nil];
        });
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    CCLOG(@"didUnsubscribeToCharacteristic");
    if ([self.sendCharacteristic isEqual:characteristic]) {
        NSString *string = @"\nserver subscribed send characteristic";
        isConnectedToCentral = NO;
        [self broadcastConnectionInfo:string];
    }

}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    for (NSData *data in dataToSend){
        [self sendDataToHost:data reliableFlag:NO];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests
{
    CFTimeInterval receiveTime = CACurrentMediaTime() * 1000;
    NSNumber *time = [NSNumber numberWithDouble:receiveTime];
    for (CBATTRequest *request in requests) {
        if ([request.characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID]]) {
            [peripheral respondToRequest:request    withResult:CBATTErrorSuccess];
            
            NSDictionary *userInfo = @{ @"data": request.value,
                                        @"peerName": @"Central",
                                        @"time": time};
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [[NSNotificationCenter defaultCenter] postNotificationName:RECEIVED_DATA_NOTIFICATION
                                                                    object:nil
                                                                  userInfo:userInfo];
            });
        }
    }
}
// end CBPeripheralManagerDelegate


@end
