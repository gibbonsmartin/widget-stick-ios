//
//  AppDelegate.m
//  widget-stick-client
//

#import "AppDelegate.h"
#import <BackgroundTasks/BackgroundTasks.h>
#include "c_schedule.h"

NSString * const kScheduleDidUpdateNotification = @"kScheduleDidUpdateNotification";
static NSString * const kBGAppRefreshTaskIdentifier = @"com.widget-stick-client.schedule.refresh";
static NSString * const kBGProcessingTaskIdentifier = @"com.widget-stick-client.schedule.processing";

@interface AppDelegate ()
@property (nonatomic, assign) UIBackgroundTaskIdentifier activeBackgroundTask;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.activeBackgroundTask = UIBackgroundTaskInvalid;

    [[BGTaskScheduler sharedScheduler] registerForTaskWithIdentifier:kBGAppRefreshTaskIdentifier
                                                          usingQueue:nil
                                                       launchHandler:^(__kindof BGTask * _Nonnull task) {
        [self handleBackgroundTask:task];
    }];

    [[BGTaskScheduler sharedScheduler] registerForTaskWithIdentifier:kBGProcessingTaskIdentifier
                                                          usingQueue:nil
                                                       launchHandler:^(__kindof BGTask * _Nonnull task) {
        [self handleBackgroundTask:task];
    }];

    return YES;
}

- (void)handleBackgroundTask:(BGTask *)task {
    [self scheduleBackgroundTasks];

    __block BOOL isExpired = NO;
    task.expirationHandler = ^{
        isExpired = YES;
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (!isExpired) {
            char buffer[512];
            int status = c_schedule_background_tick(buffer, sizeof(buffer));
            if (status == 0) {
                NSString *output = [NSString stringWithUTF8String:buffer];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kScheduleDidUpdateNotification
                                                                        object:nil
                                                                      userInfo:@{@"output": output ?: @""}];
                });
            }
        }
        [task setTaskCompletedWithSuccess:!isExpired];
    });
}

- (void)scheduleBackgroundTasks {
    BGAppRefreshTaskRequest *refreshRequest = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:kBGAppRefreshTaskIdentifier];
    refreshRequest.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:60.0];
    NSError *error = nil;
    [[BGTaskScheduler sharedScheduler] submitTaskRequest:refreshRequest error:&error];

    BGProcessingTaskRequest *processingRequest = [[BGProcessingTaskRequest alloc] initWithIdentifier:kBGProcessingTaskIdentifier];
    processingRequest.requiresNetworkConnectivity = NO;
    processingRequest.requiresExternalPower = NO;
    processingRequest.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:120.0];
    [[BGTaskScheduler sharedScheduler] submitTaskRequest:processingRequest error:&error];
}

- (void)beginBackgroundScheduleExecutionWithInput1:(NSString *)input1 input2:(NSString *)input2 {
    UIApplication *app = [UIApplication sharedApplication];
    if (self.activeBackgroundTask != UIBackgroundTaskInvalid) {
        [app endBackgroundTask:self.activeBackgroundTask];
        self.activeBackgroundTask = UIBackgroundTaskInvalid;
    }

    __weak typeof(self) weakSelf = self;
    self.activeBackgroundTask = [app beginBackgroundTaskWithName:@"CScheduleExecution" expirationHandler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.activeBackgroundTask != UIBackgroundTaskInvalid) {
            [app endBackgroundTask:strongSelf.activeBackgroundTask];
            strongSelf.activeBackgroundTask = UIBackgroundTaskInvalid;
        }
    }];

    NSString *in1Copy = [input1 copy] ?: @"";
    NSString *in2Copy = [input2 copy] ?: @"";

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char buffer[512];
        int status = c_schedule_execute([in1Copy UTF8String], [in2Copy UTF8String], buffer, sizeof(buffer));
        NSString *resultString = (status == 0)
            ? [NSString stringWithUTF8String:buffer]
            : [NSString stringWithFormat:@"Error executing schedule (code %d)", status];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kScheduleDidUpdateNotification
                                                                object:nil
                                                              userInfo:@{@"output": resultString ?: @""}];
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.activeBackgroundTask != UIBackgroundTaskInvalid) {
                [app endBackgroundTask:strongSelf.activeBackgroundTask];
                strongSelf.activeBackgroundTask = UIBackgroundTaskInvalid;
            }
        });
    });
}

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
}

@end
