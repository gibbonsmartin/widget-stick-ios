//
//  AppDelegate.h
//  widget-stick-client
//

#import <UIKit/UIKit.h>

extern NSString * const kScheduleDidUpdateNotification;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

- (void)scheduleBackgroundTasks;
- (void)beginBackgroundScheduleExecutionWithInput1:(NSString *)input1 input2:(NSString *)input2;

@end
