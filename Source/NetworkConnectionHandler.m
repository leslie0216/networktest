//
//  NetworkConnectionHandler.m
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-03-29.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "NetworkConnectionHandler.h"

@implementation NetworkConnectionHandler

-(void) setupNetwork
{
    CCLOG(@"function 'setupNetwork' is not implemented by current network type!!!");
}

-(void) startHost
{
    CCLOG(@"function 'startHost' is not implemented by current network type!!!");
}

-(void) startClient
{
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

-(void)sendData : (NSData*)data toPeer:(id)peerName reliableFlag:(BOOL)isReliable
{
    CCLOG(@"function 'sendData toPeer' is not implemented by current network type!!!");
}

-(int) connectionCount
{
    CCLOG(@"function 'connectionCount' is not implemented by current network type!!!");
    return 0;
}

-(void) stopSearch
{
    CCLOG(@"function 'stopSearch' is not implemented by current network type!!!");
}

-(void) stopAdvertise
{
    CCLOG(@"function 'stopAdvertise' is not implemented by current network type!!!");
}

-(void) disconnect
{
    CCLOG(@"function 'disconnect' is not implemented by current network type!!!");
}

@end
