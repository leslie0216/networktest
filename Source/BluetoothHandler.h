//
//  BluetoothHandler.h
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-03-30.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "NetworkConnectionHandler.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface BluetoothHandler : NetworkConnectionHandler<CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate>

@end
