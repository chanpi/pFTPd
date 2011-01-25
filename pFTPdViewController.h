//
//  pFTPdViewController.h
//  pFTPd
//
//  Created by happy on 11/01/25.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PMain.h"

@interface pFTPdViewController : UIViewController {
    IBOutlet UITextField* controlPort_;
    IBOutlet UIButton* startButton_;
    IBOutlet UIButton* stopButton_;
    
    PMain* ftpMain_;
}

@property (nonatomic, retain) UITextField* controlPort_;
- (IBAction) pressedStart:(id)sender;
- (IBAction) pressedStop:(id)sender;

@end
