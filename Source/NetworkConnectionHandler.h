//
//  NetworkConnectionHandler.h
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-03-29.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NetworkConnectionProtocol

-(void) setupNetwork;
-(void) startHost;
-(void) startClient;
-(void)sendDataToAll : (NSData*)data reliableFlag:(BOOL)isReliable;
-(void)sendDataToHost : (NSData*)data reliableFlag:(BOOL)isReliable;
-(void)sendData : (NSData*)data toPeer:(NSString*)peerName reliableFlag:(BOOL)isReliable;
-(int) connectionCount;
-(void) stopSearch;
-(void) stopAdvertise;
-(void) disconnect;

@end

@interface NetworkConnectionHandler : NSObject<NetworkConnectionProtocol>

@end

