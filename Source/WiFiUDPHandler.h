//
//  WiFiUDPHandler.h
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-04-04.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "NetworkConnectionHandler.h"
#import "CocoaAsyncSocket/GCD/GCDAsyncUdpSocket.h"

@interface WiFiUDPHandler : NetworkConnectionHandler<NSNetServiceBrowserDelegate, NSNetServiceDelegate, GCDAsyncUdpSocketDelegate>

@end
