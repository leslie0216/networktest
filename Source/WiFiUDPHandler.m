//
//  WiFiUDPHandler.m
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-04-04.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "WiFiUDPHandler.h"
#import "Parameters.h"

@interface WiFiUDPHandler()
{
    BOOL isHost;
    NSMutableDictionary<NSString*, NSNumber*> *receiveTimeDict;
}

@property (nonatomic, strong) dispatch_queue_t concurrentChatDelegateQueue;
@property (strong, nonatomic) GCDAsyncUdpSocket *socket;


// server properties
@property (strong, nonatomic) NSNetService *service;
@property (strong, nonatomic) NSMutableArray<NSData*> *clientAddresses;

// client properties
@property (strong, nonatomic) NSNetServiceBrowser *serviceBrowser;
@property(strong, nonatomic) NSMutableArray *services;


@end

@implementation WiFiUDPHandler
// begin implement NetworkConnectionProtocol
-(void) setupNetwork
{
    self.concurrentChatDelegateQueue = dispatch_queue_create("com.nc.networkteset.wifiudp",DISPATCH_QUEUE_CONCURRENT);
}

-(void) startHost
{
    isHost = YES;
    self.socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:self.concurrentChatDelegateQueue];
    
    NSError *error = nil;
    if ([self.socket bindToPort:0 error:&error]) {
        self.service = [[NSNetService alloc] initWithDomain:@"local." type:@"_ncnetworkudpteset._udp." name:@"WiFiUdpChatServer" port:[self.socket localPort]];
        
        [self.service setDelegate:self];
        
        [self.service publish];
        
    } else {
        NSString *errMsg = [NSString stringWithFormat:@"\nUnable to create socket. Error %@ with user info %@.", error, [error userInfo]];
        CCLOG(@"%@",errMsg);
        [self broadcastConnectionInfo:errMsg];
    }
}

-(void) startClient
{
    isHost = NO;
    if (self.services) {
        [self.services removeAllObjects];
    } else {
        self.services = [[NSMutableArray alloc] init];
    }
    
    self.serviceBrowser = [[NSNetServiceBrowser alloc] init];
    
    [self.serviceBrowser setDelegate:self];
    [self.serviceBrowser searchForServicesOfType:@"_ncnetworkudpteset._udp." inDomain:@"local."];
}

-(void)sendDataToAll : (NSData*)data reliableFlag:(BOOL)isReliable
{
    if (isHost) {
        for (NSData* address in self.clientAddresses) {
            [self sendData:data toAddress:address];
        }
    }
}

-(void)sendDataToHost : (NSData*)data reliableFlag:(BOOL)isReliable
{
    if (!isHost && self.socket && self.socket.isConnected) {
        [self sendData:data toAddress:nil];
    }
}

-(void)sendData : (NSData*)data toPeer:(id)peerName reliableFlag:(BOOL)isReliable
{
    if (isHost) {
        [self sendData:data toAddress:peerName];
    }
}

-(int) connectionCount
{
    if (isHost) {
        return (self.clientAddresses == nil)?0:[self.clientAddresses count];
    } else {
        return (self.socket ==  nil) ? 0 : self.socket.isConnected;
    }
}

-(void) stopSearch
{
    if (self.service) {
        [self.service stop];
        self.service = nil;
    }
    
}

-(void) stopAdvertise
{
    [self stopServiceBrowser];
}

-(void) disconnect
{
    if (self.socket) {
        if (!isHost) {
            [self sendData:[@"disconnect" dataUsingEncoding:NSUTF8StringEncoding] toAddress:nil];
        }
        [self.socket pauseReceiving];
        [self.socket close];
        [self.socket setDelegate:nil delegateQueue:nil];
        self.socket = nil;
    }
    
    [self stopSearch];
    [self stopServiceBrowser];
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

-(void)sendData:(NSData*)data toAddress:(NSData*)address
{
    /*
    NSMutableData *buffer = [[NSMutableData alloc] init];
    HEADER_TYPE dataLength = 0;
    
    dataLength = (HEADER_TYPE)[data length];
    [buffer appendBytes:&dataLength length:sizeof(HEADER_TYPE)];
    [buffer appendBytes:[data bytes] length:[data length]];*/
    
    if (isHost) {
        [self.socket sendData:data toAddress:address withTimeout:-1 tag:TAG_PING_RESPONSE];
    } else {
        [self.socket sendData:data withTimeout:-1 tag:TAG_PING_RESPONSE];
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{

}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    CCLOG(@"UDP Socket send data failed with error : %@", error);
    
}

/***********************************************************************/
/*                          SERVER FUNCTIONS                           */
/***********************************************************************/

// begin NSNetServiceDelegate
- (void)netServiceDidPublish:(NSNetService *)service
{
    NSString* publishMsg = [NSString stringWithFormat:@"\nBonjour Service Published: domain(%@) type(%@) name(%@) port(%i)", [service domain], [service type], [service name], (int)[service port]];
    CCLOG(@"%@", publishMsg);
    [self broadcastConnectionInfo:publishMsg];
    
    NSError *error;
    if (![self.socket beginReceiving:&error])
    {
        [self.socket close];
        NSString *err = [NSString stringWithFormat:@"Error starting server (recv): %@", error];
        CCLOG(@"%@", err);
        [self broadcastConnectionInfo:err];
        return;
    }
}

- (void)netService:(NSNetService *)service didNotPublish:(NSDictionary<NSString *,NSNumber *> *)errorDict
{
    NSString* publishMsg = [NSString stringWithFormat:@"\nFailed to Publish Service: domain(%@) type(%@) name(%@) - %@", [service domain], [service type], [service name], errorDict];
    CCLOG(@"%@", publishMsg);
    [self broadcastConnectionInfo:publishMsg];
}
// end NSNetServiceDelegate

// begin GCDAsyncUdpSocketDelegate
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    CFTimeInterval t = CACurrentMediaTime() * 1000;
    NSNumber *receiveTime = [NSNumber numberWithDouble:t];
    BOOL shouldDispatchData = YES;
    
    // init remote address at first time at host side
    if (isHost) {
        if (self.clientAddresses == nil) {
            self.clientAddresses = [[NSMutableArray alloc] init];
        }
        if (![self.clientAddresses containsObject:address]) {
            [self.clientAddresses addObject:address];
            
            NSString* connectionInfo = [NSString stringWithFormat:@"\nconnect with %@", address];
            CCLOG(@"%@", connectionInfo);
            [self broadcastConnectionInfo:connectionInfo];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CLIENT_CONNECTION_DONE_NOTIFICATION
                                                                    object:nil
                                                                  userInfo:nil];
            });
            
            NSString *info = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (info && [info isEqualToString:@"connect"]) {
                shouldDispatchData = NO;
            }
        } else {
            NSString *info = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (info && [info isEqualToString:@"disconnect"]) {
                shouldDispatchData = NO;
                [self.clientAddresses removeObject:address];
                [self broadcastConnectionInfo:@""];
            }
        }
    }
    
    if (shouldDispatchData) {
        //[GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
        NSDictionary *userInfo = @{ @"data": data,
                                    @"peerName": address,
                                    @"time": receiveTime};
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:RECEIVED_DATA_NOTIFICATION
                                                                object:nil
                                                              userInfo:userInfo];
        });
    }
}
// end GCDAsyncUdpSocketDelegate

/***********************************************************************/
/*                          CLIENT FUNCTIONS                           */
/***********************************************************************/
-(void)stopServiceBrowser
{
    if (self.serviceBrowser) {
        [self.serviceBrowser stop];
        self.serviceBrowser.delegate = nil;
        self.serviceBrowser = nil;
    }
}

// begin NSNetServiceBrowserDelegate
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *,NSNumber *> *)errorDict
{
    [self stopServiceBrowser];
    
    NSString *info = [NSString stringWithFormat:@"\nStart service browser failed!"];
    CCLOG(@"%@",info);
    [self broadcastConnectionInfo:info];
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
    [self stopServiceBrowser];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    [self.services removeObject:service];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    if (![self.services containsObject:service]) {
        [self.services addObject:service];
        
        NSString* info = [NSString stringWithFormat:@"\nfind service name : %@  address : %@", service.name, service.hostName];
        
        CCLOG(@"%@", info);
        [self broadcastConnectionInfo:info];
    }
    
    if (!moreComing) {
        //sort
        [self.services sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.name == %@", @"WiFiUdpChatServer"];
        NSArray *filteredArray = [self.services filteredArrayUsingPredicate:predicate];
        if ([filteredArray count] == 1) {
            NSNetService *service = [filteredArray objectAtIndex:0];
            [service setDelegate:self];
            [service resolveWithTimeout:30.0];
            
            NSString* info = [NSString stringWithFormat:@"\nfind server service name : %@  address : %@\nstart to resolve...", service.name, service.hostName];
            
            CCLOG(@"%@", info);
            [self broadcastConnectionInfo:info];
        }
    }
}
// end NSNetServiceBrowserDelegate

// begin NSNetServiceDelegate
- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary<NSString *,NSNumber *> *)errorDict
{
    [service setDelegate:nil];
    NSString* info = [NSString stringWithFormat:@"\ndid not resolve service!!!"];
    
    CCLOG(@"%@", info);
    [self broadcastConnectionInfo:info];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service
{
    NSMutableString *info;
    info = [NSMutableString stringWithFormat:@"\nservice resolved.\ntrying to connect to service..."];
    
    CCLOG(@"%@", info);
    [self broadcastConnectionInfo:info];
    
    if ([self connectWithService:service]) {
        info = [NSMutableString stringWithFormat:@"\nDid Connect with Service: domain(%@) type(%@) name(%@) port(%i)", [service domain], [service type], [service name], (int)[service port]];
    } else {
        info = [NSMutableString stringWithFormat:@"\nUnable to Connect with Service: domain(%@) type(%@) name(%@) port(%i)", [service domain], [service type], [service name], (int)[service port]];
    }
    CCLOG(@"%@", info);
    [self broadcastConnectionInfo:info];
}

- (BOOL)connectWithService:(NSNetService *)service
{
    BOOL _isConnected = NO;
    
    NSArray *addresses = [[service addresses] mutableCopy];
    
    if (!self.socket || ![self.socket isConnected]) {
        self.socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:self.concurrentChatDelegateQueue];
        
        while (!_isConnected && [addresses count]) {
            NSData *address = [addresses objectAtIndex:0];
            
            NSError *error = nil;
            if ([self.socket connectToAddress:address error:&error]) {
                _isConnected = YES;
            } else if (error) {
                CCLOG(@"Unable to connect to address. Error %@ with user info %@.", error, [error userInfo]);
            }
        }
    } else {
        _isConnected = [self.socket isConnected];
    }
    
    return _isConnected;
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address
{
    CCLOG(@"client socket equa to original? %@", [self.socket isEqual:sock] ? @"YES" : @"NO" );
    self.socket = sock;
    NSError *error;
    if (![self.socket beginReceiving:&error])
    {
        [self.socket close];
        CCLOG(@"Error starting server (recv): %@", error);
        return;
    }
    
    NSString *info = [NSString stringWithFormat:@"\nSocket Did Connect to Host: %@", address];
    CCLOG(@"%@", info);
    [self broadcastConnectionInfo:info];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CLIENT_CONNECTION_DONE_NOTIFICATION
                                                            object:nil
                                                          userInfo:nil];
    });
    
    // send garbage data to let the server know this client
    [self.socket sendData:[@"connect" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error
{
    NSString *info = [NSString stringWithFormat:@"\nConnect to server failed : %@", error];
    CCLOG(@"%@", info);
    [self broadcastConnectionInfo:info];
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
    if (self.socket == sock) {
        self.socket = nil;
        [self broadcastConnectionInfo:[NSString stringWithFormat:@"\nsocketDidDisconnect error : %@", error.localizedDescription]];
    }
}
// end NSNetServiceDelegate
@end
