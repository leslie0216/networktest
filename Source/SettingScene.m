//
//  SettingScene.m
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-03-29.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "SettingScene.h"
#import "NetworkConnectionWrapper.h"

@implementation SettingScene
-(void)btnHostClicked
{
    [self setRole:YES];
    [self switchToScene:@"ConnectionScene"];
}

-(void)btnClientClicked
{
    [self setRole:NO];
    [self switchToScene:@"ConnectionScene"];
}

-(void)btnBackClicked
{
    [self switchToScene:@"MainScene"];
}

-(void)setRole:(BOOL)isHost
{
    [[NetworkConnectionWrapper sharedWrapper] setIsHost:isHost];
}

-(void)switchToScene:(NSString *)sceneName
{
    CCScene *scene = [CCBReader loadAsScene:sceneName];
    [[CCDirector sharedDirector] replaceScene:scene];
}
@end
