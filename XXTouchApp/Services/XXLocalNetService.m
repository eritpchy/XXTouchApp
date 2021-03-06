//
//  XXLocalNetService.m
//  XXTouchApp
//
//  Created by Zheng on 8/30/16.
//  Copyright © 2016 Zheng. All rights reserved.
//

#import <spawn.h>
#import <sys/stat.h>
#import "XXLocalNetService.h"
#import "XXLocalDataService.h"
#import "NSString+XQueryComponents.h"
#import "CloudApiSdk.h"

#define CHECK_ERROR(ret) if (*error != nil) return ret;

#define GENERATE_ERROR(d) (*error = [NSError errorWithDomain:kXXErrorDomain code:[result[@"code"] integerValue] userInfo:@{ NSLocalizedDescriptionKey:result[@"message"], NSLocalizedFailureReasonErrorKey:d }])

static const char* envp[] = {"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "HOME=/var/mobile", "USER=mobile", "LOGNAME=mobile", NULL};

@implementation XXLocalNetService

+ (void)killBackboardd {
    __block int status = 0;
    double delayInSeconds = 1.0f;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
        pid_t pid;
        const char* binary = [extendDict()[@"ADD1S_PATH"] UTF8String];
        const char* args[] = {binary, "killall", "-9", "backboardd", NULL};
        posix_spawn(&pid, binary, NULL, NULL, (char* const*)args, (char* const*)envp);
        waitpid(pid, &status, 0);
        dispatch_async(dispatch_get_main_queue(), ^{
            
        });
    });
}

+ (NSDictionary *)sendSynchronousRequest:(NSString *)command
                                withData:(NSData *)data
                                   error:(NSError **)error
{
    NSURL *url = [NSURL URLWithString:[extendDict()[@"LOCAL_API"] stringByAppendingString:command]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (data) [request setHTTPBody:data];
    NSHTTPURLResponse *returningResp = nil;
    NSData *received = [NSURLConnection sendSynchronousRequest:request returningResponse:&returningResp error:error]; CHECK_ERROR(nil);
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:received options:0 error:error]; CHECK_ERROR(nil);
    return result;
}

+ (NSDictionary *)sendRemoteSynchronousRequest:(NSString *)command
                                      withForm:(NSDictionary *)dict
                                         error:(NSError **)error
{
    NSURL *url = [NSURL URLWithString:[extendDict()[@"AUTH_API"] stringByAppendingString:command]];
    if (!dict)
    {
        return nil;
    }
    NSURLRequest *request = [CloudApiSdk buildRequest:[NSString stringWithFormat:@"%@://", [url scheme]]
                                               method:@"POST"
                                                 host:[url host]
                                                 path:[url path]
                                           pathParams:nil
                                          queryParams:nil
                                           formParams:dict
                                                 body:nil
                                   requestContentType:@"application/x-www-form-urlencoded"
                                    acceptContentType:@"application/json"
                                         headerParams:nil];
    NSHTTPURLResponse *returningResp = nil;
    NSData *received = [NSURLConnection sendSynchronousRequest:request returningResponse:&returningResp error:error];
    NSDictionary *returningHeadersDict = [returningResp allHeaderFields];
    if (returningResp.statusCode != 200 &&
        returningHeadersDict[@"X-Ca-Error-Message"])
    {
        *error = [NSError errorWithDomain:kXXErrorDomain
                                     code:returningResp.statusCode
                                 userInfo:@{ NSLocalizedDescriptionKey:NSLocalizedString(returningHeadersDict[@"X-Ca-Error-Message"], nil) }];
    }
    CHECK_ERROR(nil);
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:received options:0 error:error]; CHECK_ERROR(nil);
    return result;
}

+ (NSString *)latestVersionFromRepositoryPackagesWithError:(NSError **)error {
    NSURL *url = [NSURL URLWithString:extendDict()[@"UPDATE_API"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    NSData *received = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:nil
                                                         error:error]; CHECK_ERROR(nil);
    if (!received) {
        return nil;
    }
    NSString *packagesContent = [[NSString alloc] initWithData:received encoding:NSUTF8StringEncoding];
    if (!packagesContent) {
        return nil;
    }
    NSString *targetVersion = nil;
    NSArray <NSString *> *packagesContentArray = [packagesContent componentsSeparatedByString:@"\n\n"];
    for (NSString *packageContent in packagesContentArray) {
        NSString *version = nil;
        BOOL targetPackage = NO;
        NSArray <NSString *> *packageContentLines = [packageContent componentsSeparatedByString:@"\n"];
        for (NSString *packageContentLine in packageContentLines) {
            if (packageContentLine.length > 9) {
                if ([packageContentLine rangeOfString:@"Package: "].location == 0) {
                    NSString *identifier = [packageContentLine substringFromIndex:9];
                    if ([identifier isEqualToString:extendDict()[@"UPDATE_PACKAGE"]]) {
                        targetPackage = YES;
                    }
                } else if ([packageContentLine rangeOfString:@"Version: "].location == 0) {
                    version = [packageContentLine substringFromIndex:9];
                }
            }
            
        }
        if (targetPackage) {
            targetVersion = version;
            break;
        }
    }
    return targetVersion;
}

+ (NSDictionary *)sendSynchronousRequest:(NSString *)command
                              withString:(NSString *)string
                                   error:(NSError **)error
{
    NSData *sendData = [[string stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] dataUsingEncoding:NSUTF8StringEncoding]; CHECK_ERROR(nil);
    return [self sendSynchronousRequest:command withData:sendData error:error];
}

+ (NSDictionary *)sendSynchronousRequest:(NSString *)command
                          withDictionary:(NSDictionary *)requestParams
                                   error:(NSError **)error
{
    NSData *sendData = nil;
    if (requestParams) sendData = [NSJSONSerialization dataWithJSONObject:requestParams options:0 error:error]; CHECK_ERROR(nil);
    return [self sendSynchronousRequest:command withData:sendData error:error];
}

+ (NSDictionary *)sendSynchronousRequest:(NSString *)command
                        withIntegerValue:(NSInteger)value
                                   error:(NSError **)error {
    NSString *sendString = [NSString stringWithFormat:@"%lu", (long)value]; CHECK_ERROR(nil);
    return [self sendSynchronousRequest:command withString:sendString error:error];
}

+ (BOOL)sendOneTimeAction:(NSString *)action
                    error:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:action withDictionary:nil error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0])
        return YES;
    else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localSetSelectedScript:(NSString *)scriptPath
                         error:(NSError **)error {
    NSAssert(scriptPath != nil, @"scriptPath cannot be nil");
    NSDictionary *result = [self sendSynchronousRequest:@"select_script_file" withDictionary:@{ @"filename": scriptPath } error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        [XXTGSSI.dataService setSelectedScript:scriptPath];
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localGetSelectedScriptWithError:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"get_selected_script_file" withDictionary:nil error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        if ([result[@"data"][@"filename"] hasPrefix:@"/"]) {
            [XXTGSSI.dataService setSelectedScript:result[@"data"][@"filename"]];
        } else {
            NSString *absoluteString = [result[@"data"][@"filename"] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
            if (absoluteString) {
                NSURL *absolutePath = [NSURL URLWithString:absoluteString
                                             relativeToURL:[NSURL fileURLWithPath:[XXTGSSI.dataService rootPath]]];
                [XXTGSSI.dataService setSelectedScript:[[absolutePath path] stringByRemovingPercentEncoding]];
            }
        }
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localLaunchScript:(NSString *)scriptPath
                    error:(NSError **)error {
    NSAssert(scriptPath != nil, @"scriptPath cannot be nil");
    NSDictionary *result = [self sendSynchronousRequest:@"launch_script_file"
                                         withDictionary:@{
                                                          @"filename": scriptPath,
                                                          @"envp": @{
                                                                  @"XXTOUCH_LAUNCH_VIA": @"APPLICATION",
                                                                  }
                                                          }
                                                  error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        return YES;
    } else if ([result[@"code"] isEqualToNumber:@2]) {
        GENERATE_ERROR(result[@"detail"]);
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localStopCurrentRunningScriptWithError:(NSError **)error {
    return [self sendOneTimeAction:@"recycle" error:error];
}

+ (BOOL)localLaunchSelectedScriptWithError:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"launch_script_file" withDictionary:nil error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        return YES;
    } else if ([result[@"code"] isEqualToNumber:@2]) {
        GENERATE_ERROR(result[@"detail"]);
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localGetRemoteAccessStatusWithError:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"is_remote_access_opened" withDictionary:nil error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        [XXTGSSI.dataService setRemoteAccessStatus:[result[@"data"][@"opened"] boolValue]];
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localCleanGPSCachesWithError:(NSError **)error {
    return [self sendOneTimeAction:@"clear_gps" error:error];
}

+ (BOOL)localCleanUICachesWithError:(NSError **)error {
    return [self sendOneTimeAction:@"uicache" error:error];
}

+ (BOOL)localCleanAllCachesWithError:(NSError **)error {
    return [self sendOneTimeAction:@"clear_all" error:error];
}

+ (BOOL)localRespringDeviceWithError:(NSError **)error {
    return [self sendOneTimeAction:@"respring" error:error];
}

+ (BOOL)localRestartDeviceWithError:(NSError **)error {
    return [self sendOneTimeAction:@"reboot2" error:error];
}

+ (BOOL)localRestartDaemonWithError:(NSError **)error {
    return [self sendOneTimeAction:@"restart" error:error];
}

+ (BOOL)localOpenRemoteAccessWithError:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"open_remote_access" withDictionary:nil error:error]; CHECK_ERROR(NO);
    XXLocalDataService *sharedDataService = XXTGSSI.dataService;
    if ([result[@"code"] isEqualToNumber:@0]) {
        [sharedDataService setRemoteAccessStatus:YES];
        [sharedDataService setRemoteAccessDictionary:result[@"data"]];
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localCloseRemoteAccessWithError:(NSError **)error {
    [self sendOneTimeAction:@"close_remote_access" error:error]; CHECK_ERROR(NO);
    [XXTGSSI.dataService setRemoteAccessStatus:NO];
    return YES;
}

+ (BOOL)localGetDeviceAuthInfoWithError:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"device_auth_info" withDictionary:nil error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        NSTimeInterval expirationInterval = [result[@"data"][@"expireDate"] doubleValue];
        NSTimeInterval nowInterval = [result[@"data"][@"nowDate"] doubleValue];
        if (expirationInterval > 0) {
            [XXTGSSI.dataService setExpirationDate:[NSDate dateWithTimeIntervalSince1970:expirationInterval]];
            [XXTGSSI.dataService setNowDate:[NSDate dateWithTimeIntervalSince1970:nowInterval]];
        }
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)remoteGetDeviceAuthInfoWithError:(NSError **)error {
    NSDictionary *deviceInfo = [XXTGSSI.dataService deviceInfo];
    NSMutableDictionary *sendDict = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                      @"did": deviceInfo[kXXDeviceInfoUniqueID],
                                                                                      @"sv": deviceInfo[kXXDeviceInfoSystemVersion],
                                                                                      @"v": deviceInfo[kXXDeviceInfoSoftwareVersion],
                                                                                      @"dt": deviceInfo[kXXDeviceInfoDeviceType],
                                                                                      @"ts": [@((int)[[NSDate date] timeIntervalSince1970]) stringValue],
                                                                                      @"sn": deviceInfo[kXXDeviceInfoSerialNumber],
                                                                                      }];
    NSString *checkStr = [[sendDict stringFromQueryComponents] sha1String];
    [sendDict setObject:checkStr forKey:@"sign"];
    NSDictionary *result = [self sendRemoteSynchronousRequest:@"device_info" withForm:sendDict error:error];
    CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        NSTimeInterval expirationInterval = [result[@"data"][@"expireDate"] doubleValue];
        NSTimeInterval nowInterval = [result[@"data"][@"nowDate"] doubleValue];
        if (expirationInterval > 0) {
            [XXTGSSI.dataService setExpirationDate:[NSDate dateWithTimeIntervalSince1970:expirationInterval]];
            [XXTGSSI.dataService setNowDate:[NSDate dateWithTimeIntervalSince1970:nowInterval]];
        }
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localGetDeviceInfoWithError:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"deviceinfo" withDictionary:nil error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        [XXTGSSI.dataService setDeviceInfo:[result[@"data"] copy]];
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localBindCode:(NSString *)bind
                error:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"bind_code" withString:bind error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0])
        return YES;
    else
        GENERATE_ERROR(@"");
    return NO;
}

+ (NSDictionary *)remoteBindCode:(NSString *)bind
                 error:(NSError **)error {
    NSDictionary *deviceInfo = [XXTGSSI.dataService deviceInfo];
    if (!deviceInfo) {
        return nil;
    }
    NSMutableDictionary *sendDict = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                      @"did": deviceInfo[kXXDeviceInfoUniqueID],
                                                                                      @"code": bind,
                                                                                      @"sv": deviceInfo[kXXDeviceInfoSystemVersion],
                                                                                      @"v": deviceInfo[kXXDeviceInfoSoftwareVersion],
                                                                                      @"dt": deviceInfo[kXXDeviceInfoDeviceType],
                                                                                      @"ts": [@((int)[[NSDate date] timeIntervalSince1970]) stringValue],
                                                                                      @"sn": deviceInfo[kXXDeviceInfoSerialNumber],
                                                                                      }];
    NSString *checkStr = [[sendDict stringFromQueryComponents] sha1String];
    [sendDict setObject:checkStr forKey:@"sign"];
    NSDictionary *result = [self sendRemoteSynchronousRequest:@"bind_code" withForm:sendDict error:error];
    CHECK_ERROR(nil);
    if ([result[@"code"] isEqualToNumber:@0]) {
        NSTimeInterval expirationInterval = [result[@"data"][@"expireDate"] doubleValue];
        NSTimeInterval nowInterval = [result[@"data"][@"nowDate"] doubleValue];
        if (expirationInterval > 0 || nowInterval > 0) {
            [XXTGSSI.dataService setExpirationDate:[NSDate dateWithTimeIntervalSince1970:expirationInterval]];
            [XXTGSSI.dataService setNowDate:[NSDate dateWithTimeIntervalSince1970:nowInterval]];
        }
        return result;
    }
    else
        GENERATE_ERROR(@"");
    return nil;
}

+ (BOOL)localGetApplicationListWithError:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"applist" withDictionary:nil error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        [XXTGSSI.dataService setBundles:result[@"data"]];
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localClearAppData:(NSString *)bid
                    error:(NSError **)error {
    NSAssert(bid != nil, @"bid cannot be nil");
    NSDictionary *result = [self sendSynchronousRequest:@"clear_app_data" withDictionary:@{ @"bid": bid } error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localGetVolumeActionConfWithError:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"get_volume_action_conf" withDictionary:nil error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        NSDictionary *data = result[@"data"];
        XXLocalDataService *sharedDataService = XXTGSSI.dataService;
        [sharedDataService setKeyPressConfigHoldVolumeUp:[(NSNumber *)[data objectForKey:kXXKeyPressConfigHoldVolumeUp] integerValue]];
        [sharedDataService setKeyPressConfigHoldVolumeDown:[(NSNumber *)[data objectForKey:kXXKeyPressConfigHoldVolumeDown] integerValue]];
        [sharedDataService setKeyPressConfigPressVolumeUp:[(NSNumber *)[data objectForKey:kXXKeyPressConfigPressVolumeUp] integerValue]];
        [sharedDataService setKeyPressConfigPressVolumeDown:[(NSNumber *)[data objectForKey:kXXKeyPressConfigPressVolumeDown] integerValue]];
        [sharedDataService setKeyPressConfigActivatorInstalled:[(NSNumber *)[data objectForKey:kXXKeyPressConfigActivatorInstalled] boolValue]];
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localSetHoldVolumeUpAction:(NSUInteger)option error:(NSError **)error {
    [self sendSynchronousRequest:@"set_hold_volume_up_action" withIntegerValue:option error:error]; CHECK_ERROR(NO);
    [XXTGSSI.dataService setKeyPressConfigHoldVolumeUp:option];
    return YES;
}

+ (BOOL)localSetHoldVolumeDownAction:(NSUInteger)option error:(NSError **)error {
    [self sendSynchronousRequest:@"set_hold_volume_down_action" withIntegerValue:option error:error]; CHECK_ERROR(NO);
    [XXTGSSI.dataService setKeyPressConfigHoldVolumeDown:option];
    return YES;
}

+ (BOOL)localSetPressVolumeUpAction:(NSUInteger)option error:(NSError **)error {
    [self sendSynchronousRequest:@"set_click_volume_up_action" withIntegerValue:option error:error]; CHECK_ERROR(NO);
    [XXTGSSI.dataService setKeyPressConfigPressVolumeUp:option];
    return YES;
}

+ (BOOL)localSetPressVolumeDownAction:(NSUInteger)option error:(NSError **)error {
    [self sendSynchronousRequest:@"set_click_volume_down_action" withIntegerValue:option error:error]; CHECK_ERROR(NO);
    [XXTGSSI.dataService setKeyPressConfigPressVolumeDown:option];
    return YES;
}

+ (BOOL)localGetRecordConfWithError:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"get_record_conf" withDictionary:nil error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        NSDictionary *data = result[@"data"];
        XXLocalDataService *sharedDataService = XXTGSSI.dataService;
        [sharedDataService setRecordConfigRecordVolumeUp:[(NSNumber *)[data objectForKey:kXXRecordConfigRecordVolumeUp] boolValue]];
        [sharedDataService setRecordConfigRecordVolumeDown:[(NSNumber *)[data objectForKey:kXXRecordConfigRecordVolumeDown] boolValue]];
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localSetRecordVolumeUpOnWithError:(NSError **)error {
    [self sendOneTimeAction:@"set_record_volume_up_on" error:error]; CHECK_ERROR(NO);
    [XXTGSSI.dataService setRecordConfigRecordVolumeUp:YES];
    return YES;
}

+ (BOOL)localSetRecordVolumeUpOffWithError:(NSError **)error {
    [self sendOneTimeAction:@"set_record_volume_up_off" error:error]; CHECK_ERROR(NO);
    [XXTGSSI.dataService setRecordConfigRecordVolumeUp:NO];
    return YES;
}

+ (BOOL)localSetRecordVolumeDownOnWithError:(NSError **)error {
    [self sendOneTimeAction:@"set_record_volume_down_on" error:error]; CHECK_ERROR(NO);
    [XXTGSSI.dataService setRecordConfigRecordVolumeDown:YES];
    return YES;
}

+ (BOOL)localSetRecordVolumeDownOffWithError:(NSError **)error {
    [self sendOneTimeAction:@"set_record_volume_down_off" error:error]; CHECK_ERROR(NO);
    [XXTGSSI.dataService setRecordConfigRecordVolumeDown:NO];
    return YES;
}

+ (BOOL)localGetStartUpConfWithError:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"get_startup_conf" withDictionary:nil error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        NSDictionary *data = result[@"data"];
        XXLocalDataService *sharedDataService = XXTGSSI.dataService;
        [sharedDataService setStartUpConfigSwitch:[(NSNumber *)data[kXXStartUpConfigSwitch] boolValue]];
        if ([data[kXXStartUpConfigScriptPath] hasPrefix:@"/"]) {
            [sharedDataService setStartUpConfigScriptPath:data[kXXStartUpConfigScriptPath]];
        } else {
            NSURL *absolutePath = [NSURL URLWithString:[data[kXXStartUpConfigScriptPath] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]] relativeToURL:[NSURL fileURLWithPath:[XXTGSSI.dataService rootPath]]];
            [sharedDataService setStartUpConfigScriptPath:[[absolutePath path] stringByRemovingPercentEncoding]];
        }
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localSetSelectedStartUpScript:(NSString *)scriptPath
                                error:(NSError **)error {
    NSAssert(scriptPath != nil, @"scriptPath cannot be nil");
    NSDictionary *result = [self sendSynchronousRequest:@"select_startup_script_file" withDictionary:@{ @"filename": scriptPath } error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        [XXTGSSI.dataService setStartUpConfigScriptPath:scriptPath];
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localSetStartUpRunOnWithError:(NSError **)error {
    [self sendOneTimeAction:@"set_startup_run_on" error:error]; CHECK_ERROR(NO);
    [XXTGSSI.dataService setStartUpConfigSwitch:YES];
    return YES;
}

+ (BOOL)localSetStartUpRunOffWithError:(NSError **)error {
    [self sendOneTimeAction:@"set_startup_run_off" error:error]; CHECK_ERROR(NO);
    [XXTGSSI.dataService setStartUpConfigSwitch:NO];
    return YES;
}

+ (BOOL)localGetUserConfWithError:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"get_user_conf" withDictionary:nil error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        NSDictionary *data = result[@"data"];
        XXLocalDataService *sharedDataService = XXTGSSI.dataService;
        [sharedDataService setRemoteUserConfig:[[NSMutableDictionary alloc] initWithDictionary:data]];
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localSetUserConfWithError:(NSError **)error {
    XXLocalDataService *sharedDataService = XXTGSSI.dataService;
    NSDictionary *dict = sharedDataService.remoteUserConfig;
    NSDictionary *result = [self sendSynchronousRequest:@"set_user_conf" withDictionary:dict error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        return YES;
    } else
        GENERATE_ERROR(@"");
    return NO;
}

+ (BOOL)localCheckSyntax:(NSString *)content error:(NSError **)error {
    NSDictionary *result = [self sendSynchronousRequest:@"check_syntax" withData:[content dataUsingEncoding:NSUTF8StringEncoding] error:error]; CHECK_ERROR(NO);
    if ([result[@"code"] isEqualToNumber:@0]) {
        return YES;
    } else
        GENERATE_ERROR(result[@"detail"]);
    return NO;
}

@end
