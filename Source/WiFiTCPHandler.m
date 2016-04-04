//
//  WiFiTCPHandler.m
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-04-01.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "WiFiTCPHandler.h"
#import "Parameters.h"

@interface WiFiTCPHandler()
{
    BOOL isHost;
    NSNumber *receiveTime;
}

@property (nonatomic, strong) dispatch_queue_t concurrentChatDelegateQueue;

// server properties
@property (strong, nonatomic) NSNetService *service;
@property (strong, nonatomic) NSMutableArray<GCDAsyncSocket*> *clientSockets;

// client properties
@property (strong, nonatomic) NSNetServiceBrowser *serviceBrowser;
@property (strong, nonatomic) GCDAsyncSocket* socket;
@property(strong, nonatomic) NSMutableArray *services;


@end


@implementation WiFiTCPHandler

// begin implement NetworkConnectionProtocol
-(void) setupNetwork
{
    self.concurrentChatDelegateQueue = dispatch_queue_create("com.nc.networkteset.wifitcp",DISPATCH_QUEUE_CONCURRENT);
}

-(void) startHost
{
    isHost = YES;
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.concurrentChatDelegateQueue];
    
    NSError *error = nil;
    if ([self.socket acceptOnPort:0 error:&error]) {
        self.service = [[NSNetService alloc] initWithDomain:@"local." type:@"_ncnetworkteset._tcp." name:@"WiFiChatServer" port:[self.socket localPort]];
        
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
    
    self.socket = nil;
    
    self.serviceBrowser = [[NSNetServiceBrowser alloc] init];
    
    [self.serviceBrowser setDelegate:self];
    [self.serviceBrowser searchForServicesOfType:@"_ncnetworkteset._tcp." inDomain:@"local."];
}

-(void)sendDataToAll : (NSData*)data reliableFlag:(BOOL)isReliable
{
    if (isHost) {
        for (GCDAsyncSocket* socket in self.clientSockets) {
            [self sendData:socket data:data];
        }
    }
}

-(void)sendDataToHost : (NSData*)data reliableFlag:(BOOL)isReliable
{
    if (!isHost) {
        [self sendData:self.socket data:data];
    }
}

-(void)sendData : (NSData*)data toPeer:(NSString*)peerName reliableFlag:(BOOL)isReliable
{
    if (isHost) {
        for (GCDAsyncSocket* socket in self.clientSockets) {
            if ([socket.localHost isEqualToString:peerName]) {
                [self sendData:socket data:data];
            }
        }
    }
}

-(int) connectionCount
{
    if (isHost) {
        return (self.clientSockets == nil) ? 0 : [self.clientSockets count];
    } else {
        if (self.socket) {
            return 1;
        }
    }
    return 0;
}

-(void) stopSearch
{
    CCLOG(@"function 'stopSearch' is not implemented by current network type!!!");
    //[self.service stop];
}

-(void) stopAdvertise
{
    CCLOG(@"function 'stopAdvertise' is not implemented by current network type!!!");
    [self stopServiceBrowser];
}

-(void) disconnect
{
    CCLOG(@"function disconnect");
    if (isHost) {
        if (self.clientSockets) {
            for (GCDAsyncSocket* socket in self.clientSockets)
            {
                [socket disconnect];
                socket.delegate = nil;
            }
        }
    } else {
        if (self.socket) {
            [self.socket disconnect];
            self.socket.delegate = nil;
            self.socket = nil;
        }
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

-(void)sendData:(GCDAsyncSocket*) socket data:(NSData*)data
{
    NSMutableData *buffer = [[NSMutableData alloc] init];
    HEADER_TYPE dataLength = 0;
    
    dataLength = (HEADER_TYPE)[data length];
    [buffer appendBytes:&dataLength length:sizeof(HEADER_TYPE)];
    [buffer appendBytes:[data bytes] length:[data length]];
    
    [socket writeData:buffer withTimeout:-1.0 tag:TAG_PING_RESPONSE];
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
}

- (void)netService:(NSNetService *)service didNotPublish:(NSDictionary<NSString *,NSNumber *> *)errorDict
{
    NSString* publishMsg = [NSString stringWithFormat:@"\nFailed to Publish Service: domain(%@) type(%@) name(%@) - %@", [service domain], [service type], [service name], errorDict];
    CCLOG(@"%@", publishMsg);
    [self broadcastConnectionInfo:publishMsg];
}
// end NSNetServiceDelegate

// begin GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)socket didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    if (self.clientSockets == nil) {
        self.clientSockets = [[NSMutableArray alloc]init];
    }
    [self.clientSockets addObject:newSocket];
    
    NSString *infoMsg = [NSString stringWithFormat:@"\nAccepted New Socket from %@:%hu", [newSocket connectedHost], [newSocket connectedPort]];
    CCLOG(@"%@", infoMsg);
    [self broadcastConnectionInfo:infoMsg];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CLIENT_CONNECTION_DONE_NOTIFICATION
                                                            object:nil
                                                          userInfo:nil];
    });
    
    // Read Data from Socket
    //[newSocket readDataWithTimeout:-1 tag:0];
    [newSocket readDataToLength:sizeof(HEADER_TYPE) withTimeout:-1.0 tag:TAG_HEAD];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)socket withError:(NSError *)error {
    CCLOG(@"socketDidDisconnect error : %@", error);
    
    socket.delegate = nil;

    if (isHost) {
        [self.clientSockets removeObject:socket];
    } else {
        self.socket = nil;
    }
    
    [self broadcastConnectionInfo:[NSString stringWithFormat:@"\nsocketDidDisconnect error : %@", error.localizedDescription]];

}

- (void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag
{
    if (tag == TAG_HEAD) {
        CFTimeInterval t = CACurrentMediaTime() * 1000;
        receiveTime = [NSNumber numberWithDouble:t];
        HEADER_TYPE bodyLength = 0;
        memcpy(&bodyLength, [data bytes], sizeof(HEADER_TYPE));
        [socket readDataToLength:bodyLength withTimeout:30.0 tag:TAG_BODY];
    } else if (tag == TAG_BODY) {
        NSDictionary *userInfo = @{ @"data": data,
                                    @"peerName": [socket localHost],
                                    @"time": receiveTime};

        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:RECEIVED_DATA_NOTIFICATION
                                                                object:nil
                                                              userInfo:userInfo];
        });
        // keep reading
        [socket readDataToLength:sizeof(HEADER_TYPE) withTimeout:-1.0 tag:TAG_HEAD];
    }
}

- (void)socket:(GCDAsyncSocket *)socket didWriteDataWithTag:(long)tag
{
    
}
// end GCDAsyncSocketDelegate

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
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.name == %@", @"WiFiChatServer"];
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
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.concurrentChatDelegateQueue];
        
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
// end NSNetServiceDelegate

// begin GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)socket didConnectToHost:(NSString *)host port:(uint16_t)port
{
    NSString *info = [NSString stringWithFormat:@"Socket Did Connect to Host: %@ Port: %hu", host, port];
    CCLOG(@"%@", info);
    [self broadcastConnectionInfo:info];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CLIENT_CONNECTION_DONE_NOTIFICATION
                                                            object:nil
                                                          userInfo:nil];
    });
    
    [self.socket readDataToLength:sizeof(HEADER_TYPE) withTimeout:-1.0 tag:0];
}
// end GCDAsyncSocketDelegate

@end
