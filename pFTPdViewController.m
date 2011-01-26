//
//  pFTPdViewController.m
//  pFTPd
//
//  Created by happy on 11/01/25.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "pFTPdViewController.h"

@implementation pFTPdViewController

@synthesize controlPort_;

/*
 // The designated initializer. Override to perform setup that is required before the view is loaded.
 - (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
 if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
 // Custom initialization
 }
 return self;
 }
 */

/*
 // Implement loadView to create a view hierarchy programmatically, without using a nib.
 - (void)loadView {
 }
 */


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    self.controlPort_.text = @"12345";  // root権限なら21番でできる
    //self.dataPort_.text = @"20";	// root権限なら20番でできる
}


/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [ftpMain_ release];
    [super dealloc];
}

- (IBAction) pressedStart:(id)sender {
    ftpMain_ = [[PMain alloc] init];
    int controlPort = [self.controlPort_.text integerValue];
    //int dataPort = [self.dataPort_.text integerValue];
    NSLog(@"control = %d, data = %d", controlPort, 0);
    if ([ftpMain_ ftpdStart:controlPort remote:0]) {
        NSLog(@"started");
    }
}

- (IBAction) pressedStop:(id)sender {
    [ftpMain_ stopListening];
}

@end
