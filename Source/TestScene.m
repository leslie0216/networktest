//
//  TestScene.m
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-03-29.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "TestScene.h"
#import "NetworkConnectionWrapper.h"
#import "Messages.pbobjc.h"

@interface PingInfo : NSObject
@property(strong, nonatomic)NSString* token;
@property(assign, nonatomic)CFTimeInterval startTime;
@property(strong, nonatomic)NSMutableArray *timeIntervals;
@property(assign, nonatomic)unsigned long totalCount;
@property(assign, nonatomic)unsigned long currentCount;
@property(assign, nonatomic)unsigned long number;

@end

@implementation PingInfo
@synthesize token;
@synthesize startTime;
@synthesize timeIntervals;
@synthesize totalCount;
@synthesize currentCount;
@synthesize number;

@end

@implementation TestScene
{
    CCButton *btnPing;
    CCButton *btnMode;
    CCButton *btnPingMode;
    CCButton *btnUp;
    CCButton *btnDown;
    CCLabelTTF *lbConnectionStatus;
    CCLabelTTF *lbNetworkMode;
    CCLabelTTF *lbPingInfo;
    CCLabelTTF *lbIsHost;
    CCLabelTTF *lbSendMode;
    CCLabelTTF *lbBatchInterval;
    CCLabelTTF *lbInterval;
    
    NetworkConnectionWrapper* networkWrapper;
    
    BOOL isReliable;
    NSTimer *timer;
    NSMutableArray *timerArray;
    BOOL isPing;
    //MPCLogger *myLog;
    NSMutableDictionary *pingDict;
    unsigned long count;
    CFTimeInterval batchInterval;
}

-(void)onBtnPingModeClick
{
    if ([btnPingMode.title isEqualToString:@"Ping-Pong Test"]) {
        btnPingMode.title = @"Batch Test";
        [self toggleBatchUI:YES];
    } else {
        btnPingMode.title = @"Ping-Pong Test";
        [self toggleBatchUI:NO];
    }
}

-(BOOL)isBatchTest
{
    return [btnPingMode.title isEqualToString:@"Batch Test"] ;
}

-(void)onBtnPingClicked
{
    if (isPing) {
        [self stopPing : NO];
    } else {
        [self startPing];
    }
}

-(void)onBtnModeClick
{
    isReliable = !isReliable;
    btnMode.title = isReliable ? @"Reliable mode" : @"Unreliable mode";
}

-(void)didLoadFromCCB
{
    networkWrapper = [NetworkConnectionWrapper sharedWrapper];
    
    lbIsHost.string = [networkWrapper isHost] ? @"Yes" : @"No";
    lbPingInfo.string = @"";
    btnPingMode.title = @"Ping-Pong Test";
    [self toggleBatchUI:NO];
    
    
    switch ([networkWrapper networkType]) {
        case MPC:
            isReliable = YES;
            lbSendMode.visible = YES;
            btnMode.visible = YES;
            btnMode.enabled = YES;
            btnMode.title = @"Reliable mode";
            lbNetworkMode.string = @"Mulitipeer Connectivity";
            break;
        case BLUETOOTH:
            [self disableSendMode];
            lbNetworkMode.string = @"Bluetooth";
            break;
        case WIFI_TCP:
            [self disableSendMode];
            lbNetworkMode.string = @"WiFi TCP";
            break;
        case WIFI_UDP:
            [self disableSendMode];
            lbNetworkMode.string = @"WiFi UDP";
            break;
            
        default:
            break;
    }
    
    [self updateConnectionStatus];
    
    batchInterval = 0.1;
    [self updateBatchIntervalLabel];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(peerChangedStateWithNotification:)
                                                 name:CONNECTION_STATE_CHANGED_NOTIFICATION
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleReceivedDataWithNotification:)
                                                 name:RECEIVED_DATA_NOTIFICATION
                                               object:nil];
}

-(void)toggleBatchUI:(BOOL)isVisible
{
    lbBatchInterval.visible = isVisible;
    lbInterval.visible = isVisible;
    btnUp.visible = isVisible;
    btnUp.enabled = isVisible;
    btnDown.visible = isVisible;
    btnDown.enabled = isVisible;
}

-(void)onBtnUpClicked
{
    batchInterval += 0.1;
    if (batchInterval > 1.0) {
        batchInterval = 1.0;
    }
    [self updateBatchIntervalLabel];
}

-(void)onBtnDownClicked
{
    batchInterval -= 0.1;
    if (batchInterval < 0.1) {
        batchInterval = 0.1;
    }
    [self updateBatchIntervalLabel];
}

-(void)updateBatchIntervalLabel
{
    int intervalInMs = (int)(batchInterval * 1000.0);
    lbBatchInterval.string = [NSString stringWithFormat:@"%d",intervalInMs];
}

-(void)disableSendMode
{
    lbSendMode.visible = NO;
    btnMode.visible = NO;
    btnMode.enabled = NO;
}

- (void)onExit
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (isPing) {
        [self stopPing : YES];
    }
    [networkWrapper disconnect];
    [super onExit];
}

-(void)updateConnectionStatus
{
    if ([networkWrapper currentConnectionCount] > 0) {
        lbConnectionStatus.string = @"connected";
        btnPing.enabled = YES;
        if (btnMode.visible) {
            btnMode.enabled = YES;
        }
    } else {
        if (isPing) {
            [self stopPing:NO];
        }
        lbConnectionStatus.string = @"not connected";
        btnPing.enabled = NO;
        if (btnMode.visible) {
            btnMode.enabled = NO;
        }
    }
}

- (void)peerChangedStateWithNotification:(NSNotification *)notification
{
    [self updateConnectionStatus];
}

- (void)handleReceivedDataWithNotification:(NSNotification *)notification
{
    NSData *data = [[notification userInfo] objectForKey:@"data"];
    
    PingMessage *message = [[PingMessage alloc] initWithData:data error:nil];
    if (message == nil) {
        CCLOG(@"Invalid data received!!!");
        return;
    }
    
    if (message.messageType == PingMessage_MsgType_Response) {
        NSString *token = message.token;
        
        CFTimeInterval receiveTime = [[[notification userInfo] objectForKey:@"time"] doubleValue];

        PingInfo *info = pingDict[token];
        if (info == nil) {
            CCLOG(@"Invalid ping token received!!!");
            return;
        } else if(info.totalCount == info.currentCount) {
            CCLOG(@"Token over received!!!");
            return;
        }
        
        //CCLOG(@"Receive time(r) = %f with token : %@ \n", receiveTime, token);
        //CCLOG(@"Start time(r) = %f with token : %@ \n", info.startTime, token);
        //CCLOG(@"ResponseTime = %f \n", message.responseTime);
        
        CFTimeInterval timeInterval = receiveTime - info.startTime - message.responseTime;
        CCLOG(@"Receive ping response : token : %@, timeInterval : %f", token, timeInterval);
        if (timeInterval > 300) {
            CCLOG(@"!!!High latency!!!");
        } else if(timeInterval < 0) {
            CCLOG(@"!!!Negative value!!!");
        }
        
        NSNumber *numTime = [[NSNumber alloc] initWithDouble:timeInterval];
        [timerArray addObject:numTime];
        
        [info.timeIntervals addObject:numTime];
        info.currentCount += 1;
     
#ifdef LOG_ENABLE
        // log
        NSString *log = [[NSString alloc]initWithFormat:@"%@, %f, %@, %lu, %f\n", [[notification userInfo] objectForKey:@"peerName"], timeInterval, token, info.number,CACurrentMediaTime() * 1000];
        
        [self writeLog:log];
#endif
        if (isPing) {
            if ([networkWrapper networkType] == MPC) {
                lbPingInfo.string = [[NSString alloc]initWithFormat:@"current : %f\nreceived count : %lu\ntotal count : %lu\nisReliable : %@\n", timeInterval, (unsigned long)[timerArray count], count, isReliable ? @"Yes" : @"No"];
            } else {
                lbPingInfo.string = [[NSString alloc]initWithFormat:@"current : %f\nreceived count : %lu\ntotal count : %lu\n", timeInterval, (unsigned long)[timerArray count], count];
            }
            
            if (![self isBatchTest] && info.totalCount == info.currentCount) {
                [self doPing];
            }
        }
    } else if (message.messageType == PingMessage_MsgType_Ping){
        PingMessage *packet = [[PingMessage alloc]init];
        packet.messageType = PingMessage_MsgType_Response;
        packet.token = message.token;
        packet.isReliable = message.isReliable;
        
        CFTimeInterval receiveTime = [[[notification userInfo] objectForKey:@"time"] doubleValue];
        NSTimeInterval t2 = CACurrentMediaTime() * 1000;
        packet.responseTime = t2 - receiveTime;
        
        NSData *sendData = [packet data];
        if ([networkWrapper isHost]) {
            [networkWrapper sendData:sendData toPeer:[[notification userInfo] objectForKey:@"peerName"] reliableFlag:packet.isReliable];
        } else {
            [networkWrapper sendDataToHost:sendData reliableFlag:packet.isReliable];
        }
        
        
        CCLOG(@"send response to %@ with token : %@ and local response time : %f", [[notification userInfo] objectForKey:@"peerName"], message.token, packet.responseTime);
    }
}

- (NSNumber *)standardDeviationOf:(NSArray *)array mean:(double)mean
{
    if(![array count]) return nil;
    
    double sumOfSquaredDifferences = 0.0;
    
    for(NSNumber *number in array)
    {
        double valueOfNumber = [number doubleValue];
        double difference = valueOfNumber - mean;
        sumOfSquaredDifferences += difference * difference;
    }
    
    return [NSNumber numberWithDouble:sqrt(sumOfSquaredDifferences / [array count])];
}

- (void)calculateResult
{
    unsigned long total = 0;
    unsigned long received = 0;
    NSMutableArray *allTimes = [[NSMutableArray alloc]init];
    for (id key in pingDict) {
        PingInfo *info = pingDict[key];
        
        total += info.totalCount;
        received += info.currentCount;
        
        for(NSNumber *num in info.timeIntervals) {
            [allTimes addObject:num];
        }
    }
    
    NSNumber *average = [allTimes valueForKeyPath:@"@avg.self"];
    NSNumber *min = [allTimes valueForKeyPath:@"@min.self"];
    NSNumber *max = [allTimes valueForKeyPath:@"@max.self"];
    NSNumber *std = [self standardDeviationOf:timerArray mean:[average doubleValue]];
    double lossRate = 1.0 - (double)received/total;
    NSString* lossRateStr = [NSString stringWithFormat:@"%f%%",lossRate*100];
    
    NSString* result = [NSString stringWithFormat:@"total : %lu\nreceived : %lu\nloss rate : %@\nmin : %.8f\nmax : %.8f\naverage : %.8f\nstdev : %.8f", total, received, lossRateStr, [min doubleValue], [max doubleValue], [average doubleValue], [std doubleValue]];
    
    [lbPingInfo setString:result];
}

#ifdef LOG_ENABLE
-(void)startLog
{
    if (myLog == nil) {
        myLog = [[MPCLogger alloc]init];
    }
    
    [myLog newLogFile];
    //[self writeLog:@"ping, timestamp\n"];
}

-(void)writeLog:(NSString *)log
{
    if (myLog != nil) {
        [myLog write:log];
    }
}
#endif

-(void)toggleUIExceptPingBtn:(BOOL)isEnable
{
    if ([btnMode visible]) {
        btnMode.enabled = isEnable;
    }
    
    btnPingMode.enabled = isEnable;
    
    if ([self isBatchTest]) {
        btnUp.enabled = isEnable;
        btnDown.enabled = isEnable;
    }
}

-(void)startPing
{
    isPing = YES;
    btnPing.title = @"Stop Ping";
    [self toggleUIExceptPingBtn:NO];
    
    if (timerArray == nil) {
        timerArray = [[NSMutableArray alloc] init];
    } else {
        [timerArray removeAllObjects];
    }
    
    count = 0;
    if (pingDict == nil) {
        pingDict = [[NSMutableDictionary alloc]init];
    } else {
        [pingDict removeAllObjects];
    }
#ifdef LOG_ENABLE
    [self startLog];
#endif
    timer = [NSTimer scheduledTimerWithTimeInterval:batchInterval
                                             target:self
                                           selector:@selector(doPing)
                                           userInfo:nil
                                            repeats:[self isBatchTest]];
}

-(void)stopPing : (BOOL)isExit
{
    [timer invalidate];
    isPing = NO;
    btnPing.title = @"Start Ping";
    [self toggleUIExceptPingBtn:YES];
    
    if (!isExit) {
        // calculate loss rate, min/max time interval, standard deviation after .5s
        [NSTimer scheduledTimerWithTimeInterval:1.0/2.0
                                         target:self
                                       selector:@selector(calculateResult)
                                       userInfo:nil
                                        repeats:NO];
        
    }
}

-(void)doPing
{
    PingMessage* bufMsg = [[PingMessage alloc] init];
    
    //NSString *currentPingToken = [[NSUUID UUID] UUIDString];
    NSString *currentPingToken = [NSString stringWithFormat:@"%lu", (count+1)];
    bufMsg.token = currentPingToken;
    bufMsg.isReliable = isReliable;
    bufMsg.messageType = PingMessage_MsgType_Ping;
    NSData* msg = [bufMsg data];
    CFTimeInterval startTime = CACurrentMediaTime() * 1000;
    
    CCLOG(@"Start ping : time = %f with token : %@ package size : %lu, isReliable : %@\n", startTime, bufMsg.token, (unsigned long)[msg length], bufMsg.isReliable ? @"Yes" : @"No");
    
    if ([networkWrapper isHost]) {
        [networkWrapper sendDataToAll:msg reliableFlag:isReliable];
    } else {
        [networkWrapper sendDataToHost:msg reliableFlag:isReliable];
    }
    
    PingInfo *info = [[PingInfo alloc]init];
    info.startTime = startTime;
    info.token =  currentPingToken;
    if ([networkWrapper isHost]) {
        info.totalCount = [networkWrapper currentConnectionCount];
    } else {
        info.totalCount = 1;
    }
    info.currentCount = 0;
    info.number = count + 1;
    count += info.totalCount;
    info.timeIntervals = [[NSMutableArray alloc]initWithCapacity:info.totalCount];
    
    [pingDict setValue:info forKey:currentPingToken];
}

@end
