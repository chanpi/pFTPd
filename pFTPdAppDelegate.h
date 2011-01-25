//
//  pFTPdAppDelegate.h
//  pFTPd
//
//  Created by happy on 11/01/25.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class pFTPdViewController;

@interface pFTPdAppDelegate : NSObject <UIApplicationDelegate> {
@private

}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet pFTPdViewController *viewController;

@end
