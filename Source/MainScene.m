#import "MainScene.h"
#import "Parameters.h"
#import "NetworkConnectionWrapper.h"

@implementation MainScene
-(void)btnMPCClicked
{
    [self setNetworkType:MPC];
    
    [self switchToSetting];
}

-(void)btnBluetoothClicked
{
    [self setNetworkType:BLUETOOTH];

    [self switchToSetting];
}

-(void)btnWiFiTCPClicked
{
    [self setNetworkType:WIFI_TCP];

    [self switchToSetting];
}

-(void)btnWiFiUDPClicked
{
    [self setNetworkType:WIFI_UDP];

    [self switchToSetting];
}

-(void)setNetworkType:(networkConnectionType)type
{
    [[NetworkConnectionWrapper sharedWrapper] setNetworkType:type];
}

-(void)switchToSetting
{
    CCScene *settingScene = [CCBReader loadAsScene:@"SettingScene"];
    [[CCDirector sharedDirector] replaceScene:settingScene];
}
@end
