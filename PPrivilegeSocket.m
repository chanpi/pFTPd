//
//  PPrivilegeSocket.m
//  pFTPd
//
//  Created by Happy on 11/01/20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PPrivilegeSocket.h"


@implementation PPrivilegeSocket

- (id) init {
    [super init];
    sysUtil_ = [[PSysUtil alloc] init];
    return self;
}

- (int) recvFd:(int)fd {
    return [sysUtil_ recvFd:fd];
}

- (char) getResult:(int)fd {
    char res;
    unsigned long retVal = [sysUtil_ readLoop:fd buffer:&res size:sizeof(res)];
    if (retVal != sizeof(res)) {
        NSLog(@"[ERROR] getResult:fd:");
    }
    return res;
}

- (int) getInt:(int)fd {
    int theInt = 0;
    unsigned long retVal = [sysUtil_ readLoop:fd buffer:&theInt size:sizeof(theInt)];
    if (retVal != sizeof(retVal)) {
        NSLog(@"[ERROR] getInt:fd:");
        return 0;
    }
    return theInt;
}

- (void) sendInt:(int)fd theInt:(int)theInt {
    int retVal = [sysUtil_ writeLoop:fd buffer:&theInt size:sizeof(theInt)];
    if (retVal != sizeof(theInt)) {
        NSLog(@"[ERROR] sendInt:theInt:");
    }
}

- (void) sendCommand:(int)fd command:(char)command {
    unsigned long retVal = [sysUtil_ writeLoop:fd buffer:&command size:sizeof(command)];
    if (retVal != sizeof(command)) {
        NSLog(@"[ERROR] sendCommand:command:");
    }
}

- (void) dealloc {
    [sysUtil_ release];
    [super dealloc];
}

@end
