//
//  NetworkLogger.h
//
//  Created by Chengzhao Li on 2016-03-18.
//  Copyright © 2016 Noodlecake Studios Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetworkLogger : NSObject
-(instancetype)initWithFilename: (NSString *)fn;
-(void)newLogFileWithName:(NSString *)fn;
-(void)newLogFile;
-(void)write:(NSString *)log;
@end
