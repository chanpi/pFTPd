//
//  main.m
//  pFTPd
//
//  Created by happy on 11/01/25.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

void sigpipe_handler(int signum) {
    fprintf(stderr, "SIGPIPE caught!!!!!!");
    return;
}

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    signal(SIGPIPE, sigpipe_handler);
    int retVal = UIApplicationMain(argc, argv, nil, nil);
    [pool release];
    return retVal;
}
