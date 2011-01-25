//
//  PPreLogin.m
//  pFTPd
//
//  Created by Happy on 11/01/20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PPreLogin.h"
#import "PCodes.h"

@implementation PPreLogin

- (id) init {
    self = [super init];
    ctrlIO_ = [[PControlIO alloc] init];
    return self;
}

- (void) startLogin:(PSession*)session {
    session.resCode_ = FTP_GREET;
    session.resMessage_ = @"(pFTPd 0.1 ;-)";
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleUSER:(PSession*)session {
    session.resCode_ = FTP_GIVEPWORD;
    session.resMessage_ = @"Please specify the password.";
    [ctrlIO_ sendResponseNormal:session];
}

- (BOOL) handlePASS:(PSession*)session {
    session.resCode_ = FTP_LOGINOK;
    session.resMessage_ = @"Login successful.";
    [ctrlIO_ sendResponseNormal:session];
    return YES;
}

- (void)dealloc {
    [ctrlIO_ release];
    [super dealloc];
}

@end
