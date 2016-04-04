//
//  WiFiTCPHandler.h
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-04-01.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "NetworkConnectionHandler.h"
#import "CocoaAsyncSocket/GCD/GCDAsyncSocket.h"


@interface WiFiTCPHandler : NetworkConnectionHandler<NSNetServiceBrowserDelegate,NSNetServiceDelegate, GCDAsyncSocketDelegate>

@end
