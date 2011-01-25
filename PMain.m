//
//  PMain.m
//  pFTPd
//
//  Created by Happy on 10/12/28.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PMain.h"
#import "PCommunicator.h"
#import "PSession.h"
#import <CFNetwork/CFNetwork.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#include <unistd.h>
#include <stdlib.h>

@implementation PMain

@synthesize commandPort_;
@synthesize dataPort_;

static void AcceptCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void* data, void* info) {
    // Thread Parameter
    PSession* session = [[PSession alloc] init];
    session.controlFd_ = *(CFSocketNativeHandle *)data;
    session.controlPort_ = *(unsigned short*)info;

    // get command
    PCommunicator* communicator = [[PCommunicator alloc] init];
    [NSThread detachNewThreadSelector:@selector(communicate:) toTarget:communicator withObject:session];
    [communicator release];
}


- (BOOL) ftpdStart:(int)commandPort remote:(int)dataPort {
    CFSocketRef listenSocket;
    CFSocketContext context;
    int yes = 1;    // setsockopt
    struct sockaddr_in addr;    // listen port&address
    
    self.commandPort_ = commandPort;
    self.dataPort_ = dataPort;
    
    // set context (with data port)
    context.version = 0;
    context.info = &dataPort_;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    
    // create socket
    listenSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&AcceptCallback, &context);
    if (listenSocket == NULL) {
        NSLog(@"[ERROR] CFSocketCreate");
        return NO;
    }
    
    // TIME_WAIT状態の場合、ローカルアドレスを再利用
    setsockopt(CFSocketGetNative(listenSocket), SOL_SOCKET, SO_REUSEADDR, (void*)&yes, sizeof(yes));
    
    // bind/listen
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    //addr.sin_port = htons(commandPort);
    addr.sin_port = htons(12345);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    
    NSData* address = [NSData dataWithBytes:&addr length:sizeof(addr)];
    if (CFSocketSetAddress(listenSocket, (CFDataRef)address) != kCFSocketSuccess) {
        NSLog(@"[ERROR] CFSocketSetAddress");
        CFRelease(listenSocket);
        return NO;
    }
    
    CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, listenSocket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), sourceRef, kCFRunLoopCommonModes);
    CFRelease(listenSocket);    
    return TRUE;
}

@end
