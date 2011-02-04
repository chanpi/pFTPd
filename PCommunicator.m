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
#import "PCodes.h"
#import "PDefs.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <string.h>


@interface PCommunicator (Local)
- (void) sessionInitialize:(PSession*)session;
@end


@implementation PCommunicator

- (id) init {
	self = [super init];
	priv_ = [[PPrivilegeSocket alloc] init];
	return self;
}

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
    
    [sysUtil activateKeepAlive:session.controlFd_];
    
    struct sockaddr tempAddress;
    socklen_t length = sizeof(tempAddress);
    if (getpeername(session.controlFd_, &tempAddress, &length) == 0) {
        if (session.pRemoteAddress_ == NULL) {
            session.pRemoteAddress_ = (struct Psockaddr*)malloc(sizeof(struct Psockaddr));
            fprintf(stderr, "session.pRemoteAddress_ %p", session.pRemoteAddress_);
        }
        memcpy(session.pRemoteAddress_, &tempAddress, sizeof(tempAddress));
        NSLog(@"getpeername successful.");
    }
    
    length = sizeof(tempAddress);
    if (getsockname(P_COMMAND_FD, &tempAddress, &length) == 0) {
        if (session.pLocalAddress_ == NULL) {
            session.pLocalAddress_ = (struct Psockaddr*)malloc(sizeof(struct Psockaddr));
            fprintf(stderr, "session.pLocalAddress_ %p", session.pLocalAddress_);
        }
        memcpy(session.pLocalAddress_, &tempAddress, sizeof(tempAddress));
        NSLog(@"getsockname successful.");
    }
    session.isSessonContinue_ = YES;
    
    [sysUtil release];
}

- (void) communicate:(id)param {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    PSession* session = (PSession*)param;
    PControlIO* ctrlIO = [[PControlIO alloc] init];
    PPreLogin* preLogin = [[PPreLogin alloc] init];
    PPostLogin* postLogin = [[PPostLogin alloc] init];
    int ret;

    NSLog(@"Port = %d", session.dataPort_);
    
    @try {
        [self sessionInitialize:session];
        
        // create stream
        [preLogin startLogin:session];
        
        while (1) {            
            // request
            ret = [ctrlIO getRequest:session];
            if (ret == -1) {
                // タイムアウトでセッションが切断されている可能性があるため返信できない
                [session.reqCommand_ release];
                [session.reqMessage_ release];
                session.isSessonContinue_ = NO;
                break;
            } else if (ret == -2) {
                continue;
            }
            
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
                
//            } else if ([session.reqCommand_ isEqualToString:@"EPSV"]) {
//                [postLogin handlePASV:session isEPSV:YES];
                
            } else if ([session.reqCommand_ isEqualToString:@"TYPE"]) {
                [postLogin handleTYPE:session];
                
//            } else if ([session.reqCommand_ isEqualToString:@"STAT"]) {
//                [postLogin handleSTAT:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"LIST"]) {
                [postLogin handleLIST:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"NLIST"] ||
                       [session.reqCommand_ isEqualToString:@"NLST"]) {
                [postLogin handleNLIST:session];
                
//            } else if ([session.reqCommand_ isEqualToString:@"SIZE"]) {
//                [postLogin handleSIZE:session];            
                
            } else if ([session.reqCommand_ isEqualToString:@"PORT"]) {
                [postLogin handlePORT:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"RETR"]) {
                [postLogin handleRETR:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"STOR"]) {
                [postLogin handleSTOR:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"APPE"]) {
                [postLogin handleAPPE:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"DELE"]) {
                [postLogin handleDELE:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"RNFR"]) {
                [postLogin handleRNFR:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"RNTO"]) {
                [postLogin handleRNTO:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"REST"]) {
                [postLogin handleREST:session];                

//            } else if ([session.reqCommand_ isEqualToString:@"MDTM"]) {
//                [postLogin handleMDTM:session];                
                
            } else if ([session.reqCommand_ isEqualToString:@"ABOR"]) {
                [postLogin handleABOR:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"QUIT"]) {
                [postLogin handleQUIT:session];
                
            } else if ([session.reqCommand_ isEqualToString:@"HELP"]) {
                [postLogin handleHELP:session];

            } else if ([session.reqCommand_ isEqualToString:@"NOOP"]) {
                [postLogin handleNOOP:session];

            } else {
                [postLogin handleUNKNOWN:session];
            }
            // response
            [session.reqCommand_ release];
            [session.reqMessage_ release];
            
            if (session.resCode_ == FTP_GOODBYE) {
                break;
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[ERROR] %@ communicate: %@: %@", NSStringFromClass([self class]), [exception name], [exception reason]);
    }
	@finally {
        if (session.controlFd_ != -1) {
            char tempBuffer[128];
            shutdown(session.controlFd_, SHUT_WR);
            recv(session.controlFd_, tempBuffer, sizeof(tempBuffer), 0);
            shutdown(session.controlFd_, SHUT_RDWR);
            close(session.controlFd_);
            session.controlFd_ = -1;
        }

		if (session.dataFd_ != -1) {
			close(session.dataFd_);
			session.dataFd_ = -1;
		}
		
		if (session.pasvListenFd_ != -1) {
			close(session.pasvListenFd_);
			session.pasvListenFd_ = -1;
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
}


- (int) getPasvFd:(PSession*)session {
    char res;
    int recvFd;
    [priv_ sendCommand:session.controlFd_ command:PRIV_SOCK_PASV_ACCEPT];
    res = [priv_ getResult:session.controlFd_];
    if (res == PRIV_SOCK_RESULT_BAD) {
        recvFd = [priv_ getInt:session.controlFd_];
    } else if (res != PRIV_SOCK_RESULT_OK) {
        NSLog(@"could not accept on listening socket");
		recvFd = -1;
    } else {
		recvFd = [priv_ recvFd:session.controlFd_];
	}
    return recvFd;
}

- (int) getPrivDataSocket:(PSession*)session {
    PSysUtil* sysUtil = [[PSysUtil alloc] init];
    char res;
    int recvFd;
    unsigned short port = [sysUtil sockaddrGetPort:session.pPortSockAddress_];
    [priv_ sendCommand:session.controlFd_ command:PRIV_SOCK_GET_DATA_SOCK];
    [priv_ sendInt:session.controlFd_ theInt:port];
    res = [priv_ getResult:session.controlFd_];
    if (res == PRIV_SOCK_RESULT_BAD) {
        recvFd = -1;
    } else if (res != PRIV_SOCK_RESULT_OK) {
        NSLog(@"[ERROR] could not get privileged socket");
        recvFd = -1;
    } else {
		recvFd = [priv_ recvFd:session.controlFd_];
	}
    [sysUtil release];
    return recvFd;
}

- (void) dealloc {
	[priv_ release];
	[super dealloc];
}

@end
