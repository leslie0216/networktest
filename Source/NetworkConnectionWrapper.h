//
//  NetworkConnectionWrapper.h
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-03-29.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Parameters.h"


@interface NetworkConnectionWrapper : NSObject

@property(assign, nonatomic)networkConnectionType networkType;
@property(assign, nonatomic)BOOL isHost;

+(NetworkConnectionWrapper *)sharedWrapper;

-(void)setupNetwork;
-(void)startConnection;
-(void)sendDataToAll : (NSData*)data reliableFlag:(BOOL)isReliable;
-(void)sendDataToHost : (NSData*)data reliableFlag:(BOOL)isReliable;
-(void)sendData : (NSData*)data toPeer:(id)peerName reliableFlag:(BOOL)isReliable;
-(int)currentConnectionCount;
-(void)finishConnectionSetup;
-(void)disconnect;

@end
