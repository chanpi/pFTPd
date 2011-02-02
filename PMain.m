//
//  PMain.m
//  pFTPd
//
//  Created by Happy on 10/12/28.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PMain.h"
#import "PSession.h"
#import <CFNetwork/CFNetwork.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#include <unistd.h>
#include <stdlib.h>
#include <netinet/tcp.h>

PCommunicator* communicator_;

@implementation PMain

@synthesize commandPort_;
@synthesize dataPort_;
@synthesize listenSocket_;

static void AcceptCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void* data, void* info) {
    // Thread Parameter
    PSession* session = [[PSession alloc] init];
    session.controlFd_ = *(CFSocketNativeHandle *)data;
    session.controlPort_ = *(unsigned short*)info;
    
    int option = 1;
    setsockopt(session.controlFd_, SOL_SOCKET, SO_KEEPALIVE, (const void *)&option, sizeof(option));
    
    option = 50;
    setsockopt(session.controlFd_, IPPROTO_TCP, TCP_KEEPALIVE, (const void *)&option, sizeof(option));
    /*
    option = 60;
    setsockopt(session.controlFd_, IPPROTO_TCP, TCP_KEEPINTVL, (const void *)&option, sizeof(option));

    option = 20;
    setsockopt(session.controlFd_, IPPROTO_TCP, TCP_KEEPCNT, (const void *)&option, sizeof(option));
     */

    // get commandfd
    [NSThread detachNewThreadSelector:@selector(communicate:) toTarget:communicator_ withObject:session];
}


- (BOOL) ftpdStart:(int)commandPort remote:(int)dataPort {
    CFSocketContext context;
    int yes = 1;    // setsockopt
    struct sockaddr_in addr;    // listen port&address
    
    self.commandPort_ = commandPort;
    self.dataPort_ = dataPort;
	
	communicator_ = [[PCommunicator alloc] init];
    
    // set context (with data port)
    context.version = 0;
    context.info = &dataPort_;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    
    // create socket
    listenSocket_ = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&AcceptCallback, &context);
    if (listenSocket_ == NULL) {
        NSLog(@"[ERROR] CFSocketCreate");
        return NO;
    }
    
    // TIME_WAIT状態の場合、ローカルアドレスを再利用
    setsockopt(CFSocketGetNative(listenSocket_), SOL_SOCKET, SO_REUSEADDR, (void*)&yes, sizeof(yes));
    setsockopt(CFSocketGetNative(listenSocket_), SOL_SOCKET, SO_KEEPALIVE, (void*)&yes, sizeof(yes));
    
    // bind/listen
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    //addr.sin_port = htons(commandPort);
    addr.sin_port = htons(12345);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    
    NSData* address = [NSData dataWithBytes:&addr length:sizeof(addr)];
    if (CFSocketSetAddress(listenSocket_, (CFDataRef)address) != kCFSocketSuccess) {
        NSLog(@"[ERROR] CFSocketSetAddress");
        CFRelease(listenSocket_);
        return NO;
    }
    
    CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, listenSocket_, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), sourceRef, kCFRunLoopCommonModes);
	CFRelease(sourceRef);
	
	//CFRunLoopRun();
	
    return TRUE;
}

- (void) stopListening {
	close(CFSocketGetNative(listenSocket_));
	[communicator_ release];
}

@end
