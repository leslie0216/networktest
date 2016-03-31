//
//  MPCHandler.h
//  MPCChat
//
//  Created by Chengzhao Li on 2016-02-24.
//  Copyright © 2016 Chengzhao Li. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import "NetworkConnectionHandler.h"

@interface MPCHandler : NetworkConnectionHandler<MCSessionDelegate, MCNearbyServiceBrowserDelegate>

@end
