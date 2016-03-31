//
//  ConnectionScene.m
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-03-29.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "ConnectionScene.h"
#import "NetworkConnectionWrapper.h"


@implementation ConnectionScene
{
    CCButton *btnDone;
    CCLabelTTF *lbConnectionStatus;
    NetworkConnectionWrapper* networkWrapper;
}

-(void)didLoadFromCCB
{
    btnDone.enabled = NO;
    lbConnectionStatus.string = @"";
    
    networkWrapper = [NetworkConnectionWrapper sharedWrapper];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(foundPeerWithNotification:)
                                                 name:SERVER_DID_FOUND_CLIENT_NOTIFICATION
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(peerChangedStateWithNotification:)                                                 name:CONNECTION_STATE_CHANGED_NOTIFICATION
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(startBrowserFailedNotification:)                                                 name:SERVER_DID_NOT_START_NOTIFICATION
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(serverClientConnectionDoneNotification:)                                                 name:SERVER_CLIENT_CONNECTION_DONE_NOTIFICATION
                                               object:nil];
    
    // Init network
    [self updateStatus:@"\ninitialize network..."];
    [networkWrapper setupNetwork];
    
    // Start network connection
    [self updateStatus:[NSString stringWithFormat:@"\nthis device works as %@",[networkWrapper isHost] ? @"Host" : @"Client"]];
    [self updateStatus:@"\nconnecting..."];
    [networkWrapper startConnection];
    
}

-(void)btnDoneClicked
{
    [networkWrapper finishConnection];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    CCScene *testScene = [CCBReader loadAsScene:@"TestScene"];
    [[CCDirector sharedDirector] replaceScene:testScene];
}

-(void)btnBackClicked
{
    [networkWrapper finishConnection];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    CCScene *SettingScene = [CCBReader loadAsScene:@"SettingScene"];
    [[CCDirector sharedDirector] replaceScene:SettingScene];
}

-(void)updateStatus:(NSString *)status
{
    lbConnectionStatus.string = [lbConnectionStatus.string stringByAppendingString:status];
}

- (void)foundPeerWithNotification:(NSNotification *)notification
{
    NSString* remoteName = [[notification userInfo] objectForKey:@"peerName"];
    [self updateStatus:[NSString stringWithFormat:@"\nfound %@\ntry to connect to %@...",remoteName, remoteName]];
}

- (void)peerChangedStateWithNotification:(NSNotification *)notification
{
    NSString *string = [[notification userInfo] objectForKey:@"connectionInfo"];
    [self updateStatus:string];
}

- (void)startBrowserFailedNotification:(NSNotification *)notification
{
    NSError* error = [[notification userInfo] objectForKey:@"error"];
    [self updateStatus:[NSString stringWithFormat:@"\nstart browser failed : %@",error]];
}

- (void)serverClientConnectionDoneNotification:(NSNotification *)notification
{
    if ([networkWrapper currentConnectionCount] > 0) {
        btnDone.enabled = YES;
    } else {
        btnDone.enabled = NO;
    }
}


@end
