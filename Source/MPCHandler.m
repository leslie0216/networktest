//
//  MPCHandler.m
//  MPCChat
//
//  Created by Chengzhao Li on 2016-02-24.
//  Copyright © 2016 Chengzhao Li. All rights reserved.
//

#import "MPCHandler.h"
#import "Messages.pbobjc.h"
#import "Parameters.h"

@interface MPCHandler()
{
    BOOL isHost;
    MCPeerID *hostPeerID;
}

@property(nonatomic, strong) MCPeerID *peerID;
@property(nonatomic, strong) MCSession *session;
@property(nonatomic, strong) MCNearbyServiceBrowser *browser;
@property(nonatomic, strong) MCAdvertiserAssistant *advertiser;
@end

@implementation MPCHandler

// begin implement NetworkConnectionProtocol

-(void) setupNetwork
{
    hostPeerID = nil;
    isHost = NO;
    [self setupPeerWithDisplayName:[UIDevice currentDevice].name];
    [self setupSession];
}

-(void) startHost
{
    isHost = YES;
    [self setupBrowser];
}

-(void) startClient
{
    isHost = NO;
    [self advertiseSelf:YES];
}

-(void)sendDataToAll : (NSData*)data reliableFlag:(BOOL)isReliable
{
    if (isHost) {
        MCSessionSendDataMode mode = isReliable ? MCSessionSendDataReliable : MCSessionSendDataUnreliable;
        
        NSError *error;
        [self.session sendData:data toPeers:self.session.connectedPeers withMode:mode error:&error];
        
        if (error != nil) {
            CCLOG(@"send data failed : %@", error);
        }
    }
}

-(void)sendDataToHost : (NSData*)data reliableFlag:(BOOL)isReliable
{
    if (!isHost) {
        MCSessionSendDataMode mode = isReliable ? MCSessionSendDataReliable : MCSessionSendDataUnreliable;
        
        NSArray *host = [NSArray arrayWithObject:hostPeerID];
        NSError *error;

        [self.session sendData:data toPeers:host withMode:mode error:&error];
        
        if (error != nil) {
            CCLOG(@"send data failed : %@", error);
        }
    }
}

-(void)sendData : (NSData*)data toPeer:(id)peerName reliableFlag:(BOOL)isReliable
{
    for(MCPeerID* peer in self.session.connectedPeers)
    {
        if ([[peer displayName] isEqualToString:peerName]) {
            MCSessionSendDataMode mode = isReliable ? MCSessionSendDataReliable : MCSessionSendDataUnreliable;
            NSError *error;
            NSArray *target = [NSArray arrayWithObject:peer];
            [self.session sendData:data toPeers:target withMode:mode error:&error];
            
            if (error != nil) {
                CCLOG(@"send data failed : %@", error);
            }
            
            break;
        }
    }
}

-(int) connectionCount
{
    if (self.session  != nil) {
        return self.session.connectedPeers.count;
    }
    
    return 0;
}

-(void) stopSearch
{
    if (self.session != nil)
    {
        if (self.browser) {
            [self.browser stopBrowsingForPeers];
            self.browser.delegate = nil;
            self.browser = nil;
        }
    }
}

-(void) stopAdvertise
{
    [self advertiseSelf:NO];
}

-(void) disconnect
{
    [self stopSearch];
    [self stopAdvertise];
    if (self.session) {
        [self.session disconnect];
        self.session = nil;
    }
}

// end implement NetworkConnectionProtocol

- (void) setupPeerWithDisplayName:(NSString *)displayName
{
    self.peerID = [[MCPeerID alloc] initWithDisplayName:displayName];
}

- (void) setupSession
{
    self.session = [[MCSession alloc] initWithPeer:self.peerID];
    self.session.delegate = self;
}

- (void) setupBrowser
{
    if(self.browser) {
        [self.browser stopBrowsingForPeers];
        self.browser.delegate = nil;
        self.browser = nil;
    }
    
    hostPeerID = self.peerID;
    
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.peerID serviceType:@"ncnetworktest"];
    self.browser.delegate = self;
    [self.browser startBrowsingForPeers];
}

- (void) advertiseSelf:(BOOL)advertise
{
    if (advertise) {
        self.advertiser = [[MCAdvertiserAssistant alloc] initWithServiceType:@"ncnetworktest" discoveryInfo:nil session:self.session];
        [self.advertiser start];
    } else {
        [self.advertiser stop];
        self.advertiser = nil;
    }
}

// begin MCNearbyServiceBrowserDelegate
-(void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info
{
    CCLOG(@"MCNearbyServiceBrowser foundPeer..  %@", peerID);
    
    NSDictionary *userInfo = @{ @"peerName": [peerID displayName]};
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_DID_FOUND_CLIENT_NOTIFICATION
                                                            object:nil
                                                          userInfo:userInfo];
    });
    
    // connect to the peer
    [self.browser invitePeer:peerID toSession:self.session withContext:nil timeout:30];
}

-(void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    
}

-(void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    CCLOG(@"start browser failed!!! : %@", error);
    [self stopSearch];
    
    NSDictionary *userInfo = @{ @"error": error};

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CLIENT_DID_NOT_START_NOTIFICATION
                                                            object:nil
                                                          userInfo:userInfo];
    });
    
}
// end MCNearbyServiceBrowserDelegate

// begin MCSessionDelegate
- (void) session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    if (!isHost && hostPeerID == nil) {
        hostPeerID = peerID;
    }
    
    NSMutableString *string = [[NSMutableString alloc] init];
    if (state == MCSessionStateConnected) {
        [string appendFormat:@"\nconnected with %@",[peerID displayName]];
    } else if (state == MCSessionStateNotConnected)
    {
        [string appendFormat:@"\nlost connection with %@",[peerID displayName]];
        if (peerID == hostPeerID) {
            [self disconnect];
        }
    }
    
    NSDictionary *userInfo = @{ @"connectionInfo": string};
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:CONNECTION_STATE_CHANGED_NOTIFICATION
                                                            object:nil
                                                          userInfo:userInfo];
    });

    if (self.session.connectedPeers.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CLIENT_CONNECTION_DONE_NOTIFICATION
                                                                object:nil
                                                              userInfo:nil];
        });
    }
}

- (void) session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    CFTimeInterval t = CACurrentMediaTime() * 1000;
    NSNumber *time = [NSNumber numberWithDouble:t];
    
    NSDictionary *userInfo = @{ @"data": data,
                                @"peerName": [peerID displayName],
                                @"time": time};
    
    dispatch_async(dispatch_get_main_queue(), ^{

        [[NSNotificationCenter defaultCenter] postNotificationName:RECEIVED_DATA_NOTIFICATION
                                                        object:nil
                                                      userInfo:userInfo];
    });
}

- (void) session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    
}

- (void) session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    
}

- (void) session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    
}

// end MCSessionDelegate

@end