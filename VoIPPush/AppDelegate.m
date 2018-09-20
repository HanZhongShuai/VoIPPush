//
//  AppDelegate.m
//  VoIPPush
//
//  Created by HS on 2018/9/20.
//  Copyright © 2018 HS. All rights reserved.
//

#import "AppDelegate.h"
#import <UserNotifications/UserNotifications.h>
#import <PushKit/PushKit.h>

@interface AppDelegate ()<PKPushRegistryDelegate>
{
    NSString *deviceTokenStr;
    NSString *voipDeviceTokenStr;
    
    UILocalNotification *callNotification;
    
    NSTimer *timer;
    NSInteger showTimes;
}

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    return YES;
}

#pragma mark - PushNotification

- (void)registerPushNotification {
    
    //voip delegate
    PKPushRegistry *pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    pushRegistry.delegate = self;
    pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center setNotificationCategories:[self createNotificationCategoryActions]];
        [center requestAuthorizationWithOptions:UNAuthorizationOptionBadge|UNAuthorizationOptionSound|UNAuthorizationOptionAlert completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] registerForRemoteNotifications];
                });
            }
            else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                });
            }
        }];
    }
    else {
        UIUserNotificationType userNotificationTypes = (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound);
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes  categories:[self createNotificationCategoryActions]];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
}

-(NSSet *)createNotificationCategoryActions{
    if (@available(iOS 10.0, *)) {
        //定义按钮的交互button action
        UNNotificationAction * likeButton = [UNNotificationAction actionWithIdentifier:@"acceptVideoCall" title:@"accept" options:UNNotificationActionOptionAuthenticationRequired|UNNotificationActionOptionDestructive|UNNotificationActionOptionForeground];
        UNNotificationAction * dislikeButton = [UNNotificationAction actionWithIdentifier:@"ignoreVideoCall" title:@"ignore" options:UNNotificationActionOptionAuthenticationRequired|UNNotificationActionOptionDestructive|UNNotificationActionOptionForeground];
        
        //将这些action带入category
        UNNotificationCategory * choseCategory = [UNNotificationCategory categoryWithIdentifier:@"videoCallCategory" actions:@[likeButton,dislikeButton] intentIdentifiers:@[@"acceptVideoCall",@"ignoreVideoCall"] options:UNNotificationCategoryOptionNone];
        return [NSSet setWithObject:choseCategory];
    }
    else {
        
        //初始化action
        UIMutableUserNotificationAction* action1 =         [[UIMutableUserNotificationAction alloc] init];
        //设置action的identifier
        [action1 setIdentifier:@"acceptVideoCall"];
        //title就是按钮上的文字
        [action1 setTitle:@"accept"];
        //设置点击后在后台处理,还是打开APP
        [action1 setActivationMode:UIUserNotificationActivationModeBackground];
        //是不是像UIActionSheet那样的Destructive样式
        [action1 setDestructive:YES];
        //在锁屏界面操作时，是否需要解锁
        [action1 setAuthenticationRequired:YES];
        
        UIMutableUserNotificationAction* action2 = [[UIMutableUserNotificationAction alloc] init];
        [action2 setIdentifier:@"ignoreVideoCall"];
        [action2 setTitle:@"ignore"];
        [action2 setActivationMode:UIUserNotificationActivationModeBackground];
        [action2 setDestructive:NO];
        [action2 setAuthenticationRequired:NO];
        
        //一个category包含一组action，作为一种显示样式
        UIMutableUserNotificationCategory* category = [[UIMutableUserNotificationCategory alloc] init];
        [category setIdentifier:@"videoCallCategory"];
        //minimal作为banner样式时使用，最多只能有2个actions；default最多可以有4个actions
        [category setActions:@[action1,action2] forContext:UIUserNotificationActionContextMinimal];
        
        return [NSSet setWithObject:category];
    }
    
}

- (void)registerForRemoteNotificationsWithDeviceToken
{
    //注册token  token 上传服务器
    
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    NSLog(@"didRegisterUserNotificationSettings");
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    NSRange range = NSMakeRange(1,[[deviceToken description] length]-2);
    deviceTokenStr = [[deviceToken description] substringWithRange:range];
    NSLog(@"deviceTokenStr==%@",deviceTokenStr);
    
    [self registerForRemoteNotificationsWithDeviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSLog(@"Fail to Register For Remote Notificaions With Error :error = %@",error.description);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    //    [self.push application:application didReceiveRemoteNotification:userInfo];
    [self doNotificationWithInfo:userInfo isLaunching:NO];
}

#pragma mark - PKPushRegistryDelegate

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type{
    if([credentials.token length] == 0) {
        NSLog(@"voip token NULL");
        return;
    }
    //应用启动获取token，并上传服务器
    voipDeviceTokenStr = [[[[credentials.token description] stringByReplacingOccurrencesOfString:@"<"withString:@""]
              stringByReplacingOccurrencesOfString:@">" withString:@""]
             stringByReplacingOccurrencesOfString:@" " withString:@""];
    //token上传服务器
    [self registerForRemoteNotificationsWithDeviceToken];
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type{
    BOOL isCalling = false;
    switch ([UIApplication sharedApplication].applicationState) {
        case UIApplicationStateActive: {
            isCalling = false;
        }
            break;
        case UIApplicationStateInactive: {
            isCalling = false;
        }
            break;
        case UIApplicationStateBackground: {
            isCalling = true;
        }
            break;
        default:
            isCalling = true;
            break;
    }
    
    if (isCalling){
        //本地通知，实现响铃效果
        [self onCallRing:@"XXX"];
    }
}

#pragma mark - Video deal

- (void)onCallRing:(NSString *)CallerName {
    showTimes = 0;
    [self onCancelRing];
    timer = [NSTimer scheduledTimerWithTimeInterval:4 target:self selector:@selector(repeatTimer:) userInfo:CallerName repeats:YES];
    [self addLocationNotifition:CallerName];
    [self performSelector:@selector(onCancelRing) withObject:nil afterDelay:18];
}

- (void)repeatTimer:(NSTimer *)timer
{
    NSString *CallerName = timer.userInfo;
    [self addLocationNotifition:CallerName];
}

- (void)addLocationNotifition:(NSString *)CallerName
{
    showTimes++;
    if (showTimes > 3) {
        [self onCancelRing];
        return;
    }
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
        content.body =[NSString localizedUserNotificationStringForKey:[NSString
                                                                       stringWithFormat:@"%@%@", CallerName,
                                                                       @"邀请你进行通话。。。。"] arguments:nil];;
        UNNotificationSound *customSound = [UNNotificationSound soundNamed:@"3333.wav"];
        content.sound = customSound;
        UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger
                                                      triggerWithTimeInterval:0.1 repeats:NO];
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[NSString stringWithFormat:@"Voip_Push_%ld",showTimes]
                                                                              content:content trigger:trigger];
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            
        }];
    }else {
        
        callNotification = [[UILocalNotification alloc] init];
        callNotification.alertBody = [NSString
                                      stringWithFormat:@"%@%@", CallerName,
                                      @"邀请你进行通话。。。。"];
        
        callNotification.soundName = @"3333.wav";
        [[UIApplication sharedApplication]
         presentLocalNotificationNow:callNotification];
        
    }
}

- (void)onCancelRing {
    //取消通知栏
    if (timer && timer.isValid) {
        [timer invalidate];
        timer = nil;
    }
    if (@available(iOS 10.0, *)) {
        //        NSMutableArray *arraylist = [[NSMutableArray alloc]init];
        //        [arraylist addObject:@"Voip_Push"];
        [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
    }else {
        [[UIApplication sharedApplication] cancelLocalNotification:callNotification];
    }
    
}

#pragma mark - normal push deal

- (void)doLocalNotificationWithInfo:(NSDictionary *)userInfo {
    
}

- (void)doNotificationWithInfo:(NSDictionary *)userInfo isLaunching:(BOOL)isLaunching{
    
}

- (void)cancelPushNotification{
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center removeAllPendingNotificationRequests];
    }
    //    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
}



- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
