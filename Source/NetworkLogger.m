//
//  NetworkLogger.m
//
//  Created by Chengzhao Li on 2016-03-18.
//  Copyright © 2016 Noodlecake Studios Inc. All rights reserved.
//

#import "NetworkLogger.h"

@interface NetworkLogger()
{
    NSString *filename;
    NSString *fileFullpath;
    NSFileHandle *fileHandle;
}

@end

@implementation NetworkLogger
-(instancetype)initWithFilename:(NSString *)fn
{
    self = [super init];
    
    if (self) {
        if (![self createLogWithFilename:fn]) {
            CCLOG(@"!!!!!!!!Cannot create log file with name %@", fn);
        };
    }
    
    return self;
}

-(void)newLogFileWithName:(NSString *)fn
{
    if (![self createLogWithFilename:fn]) {
        CCLOG(@"!!!!!!!!Cannot create log file with name %@", fn);
    };
}

-(void)newLogFile
{
    if (![self createLogWithFilename:@""]) {
        CCLOG(@"!!!!!!!!Cannot create log file");
    };
}

-(BOOL)createLogWithFilename:(NSString *)fn
{
    if ([fn isEqualToString:@""]) {
        filename = @".txt";
    } else {
        filename = [NSString stringWithFormat:@"_%@.txt", fn];
    }
    
    
    NSString* filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *info = [bundle infoDictionary];
    NSString *prodName = [info objectForKey:@"CFBundleDisplayName"];
    
    NSDate *date = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth |NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitNanosecond) fromDate:date];
    NSInteger year = [components year];
    NSInteger month = [components month];
    NSInteger day = [components day];
    NSInteger hour = [components hour];
    NSInteger minute = [components minute];
    NSInteger second = [components second];
    
    NSString *filePrefix = [NSString stringWithFormat:@"%@_%ld_%ld_%ld_%ld_%ld_%ld", prodName,(long)year, (long)month, (long)day, (long)hour, (long)minute, (long)second];
    NSString *fullFilename = [filePrefix stringByAppendingString:filename];
    
    fileFullpath = [filePath stringByAppendingPathComponent:fullFilename];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileFullpath]) {
        if ([[NSFileManager defaultManager] createFileAtPath:fileFullpath contents:nil attributes:nil]) {
            fileHandle = [NSFileHandle fileHandleForWritingAtPath:fileFullpath];
            //test
            //[fileHandle seekToEndOfFile];
            //[fileHandle writeData:[@"test\n" dataUsingEncoding:NSUTF8StringEncoding]];
            //
            return  TRUE;
        } ;
    } else {
        // try to resolve file name conflict
        NSInteger nanosecond = [components nanosecond];
        filePrefix = [filePrefix stringByAppendingString:[NSString stringWithFormat:@"%ld", (long)nanosecond]];
        NSString *fullFilename = [filePrefix stringByAppendingString:filename];
        fileFullpath = [filePath stringByAppendingPathComponent:fullFilename];
        if (![[NSFileManager defaultManager] fileExistsAtPath:fileFullpath]) {
            if ([[NSFileManager defaultManager] createFileAtPath:fileFullpath contents:nil attributes:nil]) {
                fileHandle = [NSFileHandle fileHandleForWritingAtPath:fileFullpath];
                return  TRUE;
            } ;
        }
    }
    
    return FALSE;
}

-(void)write:(NSString *)log
{
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:[log dataUsingEncoding:NSUTF8StringEncoding]];
}
@end
