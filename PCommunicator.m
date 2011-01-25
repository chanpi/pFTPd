//
//  PCommunicator.m
//  pFTPd
//
//  Created by Happy on 11/01/06.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PCommunicator.h"
#import "PSession.h"
#import "PPreLogin.h"
#import "PPostLogin.h"
#import "PSysUtil.h"
#import "PPrivilegeSocket.h"
#import "PCodes.h"
#import "PDefs.h"

#include <sys/types.h>
#include <netinet/in.h>
#include <unistd.h>
#include <string.h>


@interface PCommunicator (Local)
- (void) sessionInitialize:(PSession*)session;
@end


@implementation PCommunicator

- (void) sessionInitialize:(PSession*)session {
    PSysUtil* sysUtil = [[PSysUtil alloc] init];
    
    // dup
    // We must satisfy the contract: command socket on fd 0, 1, 2
    // これはこのタイミングではないかも。Exceptionに入ってしまうし、throwさせなくてもfd0をdupすると相手が死んでしまう
    // これはforkした場合に親子プロセスが通信するために行うものか？
    [sysUtil dupFd2:session.controlFd_ newFd:0];
    [sysUtil dupFd2:session.controlFd_ newFd:1];
    /*
     [sysUtil dupFd2:session.controlFd_ newFd:2];        
     */
    
    // main: session_init途中！！
    struct Psockaddr tempAddress;
    //[sysUtil getPeerName:session.controlFd_ pSockAddrPtr:&tempAddress];
    [sysUtil getPeerName:P_COMMAND_FD pSockAddrPtr:&tempAddress];
    if (session.pRemoteAddress_ == NULL) {
        session.pRemoteAddress_ = (struct Psockaddr*)malloc(sizeof(struct Psockaddr));
    }
    memcpy(session.pRemoteAddress_, &tempAddress, sizeof(tempAddress));
    
    //[sysUtil getSockName:session.controlFd_ pSockAddrPtr:&tempAddress];
    [sysUtil getSockName:P_COMMAND_FD pSockAddrPtr:&tempAddress];
    if (session.pLocalAddress_ == NULL) {
        session.pLocalAddress_ = (struct Psockaddr*)malloc(sizeof(struct Psockaddr));
    }
    memcpy(session.pLocalAddress_, &tempAddress, sizeof(tempAddress));
    
    
    /*
     if (anonymousEnabled) {
     // ftp_usernameでログイン
     }
     */
    [sysUtil release];
}


- (void) communicate:(id)param {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    PSession* session = (PSession*)param;
    PControlIO* ctrlIO = [[PControlIO alloc] init];
    PPreLogin* preLogin = [[PPreLogin alloc] init];
    PPostLogin* postLogin = [[PPostLogin alloc] init];
    int ret;

    [param release];
    
    NSLog(@"Port = %d", session.dataPort_);
    
    @try {
        [self sessionInitialize:session];
        
        // create stream
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, session.controlFd_, &readStream, &writeStream);
        if (readStream == NULL || writeStream == NULL) {
            NSException* ex =[NSException exceptionWithName:@"PException" reason:@"CFStreamCreatePairWithSocket()" userInfo:nil];
            @throw ex;
        }
        
        session.readStream_ = readStream;
        session.writeStream_ = writeStream;
        
        CFWriteStreamOpen(session.writeStream_);
        CFReadStreamOpen(session.readStream_);
        
        [preLogin startLogin:session];
        
        while (1) {
            // request
            ret = [ctrlIO getRequest:session];
            
            NSLog(@"[req] %@ %@", session.reqCommand_, session.reqMessage_);
            
            // check
            if ([session.reqCommand_ isEqualToString:@"USER"]) {
                [preLogin handleUSER:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"PASS"]) {
                if ([preLogin handlePASS:session]) {
                    [preLogin release];
                    preLogin = nil;
                }
                
            } else if ([session.reqCommand_ isEqualToString:@"SYST"]) {
                [postLogin handleSYST:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"FEAT"]) {
                [postLogin handleFEAT:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"PWD"] ||
                       [session.reqCommand_ isEqualToString:@"XPWD"]) {
                [postLogin handlePWD:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"CWD"]) {
                [postLogin handleCWD:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"CDUP"]) {
                [postLogin handleCDUP:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"MKD"]) {
                [postLogin handleMKD:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"RMD"]) {
                [postLogin handleRMD:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"PASV"] ||
                       [session.reqCommand_ isEqualToString:@"P@SW"]) {
                [postLogin handlePASV:session isEPSV:NO];
                
            } else if ([session.reqCommand_ isEqualToString:@"EPSV"]) {
                [postLogin handlePASV:session isEPSV:YES];
                
            } else if ([session.reqCommand_ isEqualToString:@"TYPE"]) {
                [postLogin handleTYPE:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"LIST"]) {
                [postLogin handleLIST:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"NLIST"]) {
                [postLogin handleNLIST:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"SIZE"]) {
                [postLogin handleSIZE:session];            
                
            } else if ([session.reqCommand_ isEqualToString:@"PORT"]) {
                [postLogin handlePORT:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"RETR"]) {
                [postLogin handleRETR:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"STOR"]) {
                [postLogin handleSTOR:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"QUIT"]) {
                [postLogin handleQUIT:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"HELP"]) {
                [postLogin handleHELP:session];
                
            } else {
                [postLogin handleUNKNOWN:session];
            }
            // response
            [session.reqCommand_ release];
            [session.reqMessage_ release];
            
            if (ret == -1 || session.resCode_ == FTP_GOODBYE) {
                break;
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[ERROR] %@ communicate: %@: %@", NSStringFromClass([self class]), [exception name], [exception reason]);
    }

    close(session.controlFd_);
    
    if (session.readStream_ != NULL) {
        CFReadStreamClose(session.readStream_);
        session.readStream_ = NULL;
    }
    if (session.writeStream_ != NULL) {
        CFWriteStreamClose(session.writeStream_);
        session.writeStream_ = NULL;
    }
    
    if (preLogin != nil) {
        [preLogin release];
        preLogin = nil;
    }
    
    [ctrlIO release];
    [postLogin release];
    [session release];  // 必ずrelease
    [pool release];
}


- (int) getPasvFd:(PSession*)session {
    PPrivilegeSocket* priv = [[PPrivilegeSocket alloc] init];
    char res;
    int recvFd;
    [priv sendCommand:session.controlFd_ command:PRIV_SOCK_PASV_ACCEPT];
    res = [priv getResult:session.controlFd_];
    if (res == PRIV_SOCK_RESULT_BAD) {
        return [priv getInt:session.controlFd_];
    } else if (res != PRIV_SOCK_RESULT_OK) {
        NSLog(@"could not accept on listening socket");
    }
    recvFd = [priv recvFd:session.controlFd_];
    [priv release];
    return recvFd;
}

- (int) getPrivDataSocket:(PSession*)session {
    PSysUtil* sysUtil = [[PSysUtil alloc] init];
    PPrivilegeSocket* priv = [[PPrivilegeSocket alloc] init];
    char res;
    int recvFd;
    unsigned short port = [sysUtil sockaddrGetPort:session.pPortSockAddress_];
    [priv sendCommand:session.controlFd_ command:PRIV_SOCK_GET_DATA_SOCK];
    [priv sendInt:session.controlFd_ theInt:port];
    res = [priv getResult:session.controlFd_];
    if (res == PRIV_SOCK_RESULT_BAD) {
        recvFd = -1;
    } else if (res != PRIV_SOCK_RESULT_OK) {
        NSLog(@"[ERROR] could not get privileged socket");
        recvFd = -1;
    }
    recvFd = [priv recvFd:session.controlFd_];
    [priv release];
    [sysUtil release];
    return recvFd;
}


@end
