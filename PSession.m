//
//  PSession.m
//  pFTPd
//
//  Created by Happy on 11/01/18.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PSession.h"

@implementation PSession

@synthesize controlFd_;
@synthesize controlPort_;
@synthesize pLocalAddress_;
@synthesize pRemoteAddress_;
@synthesize isSessonContinue_;

@synthesize pasvListenFd_;
@synthesize dataFd_;
@synthesize dataProgress_;
@synthesize dataPort_;
@synthesize pPortSockAddress_;

@synthesize isAnonymous_;

@synthesize restartPos_;
@synthesize isAscii_;
@synthesize isEpsvAll_;
@synthesize isPasv_;
@synthesize isAbort_;

@synthesize reqCommand_;
@synthesize reqMessage_;
@synthesize resCode_;
@synthesize resSep_;
@synthesize resMessage_;

@synthesize isControlUseSSL_;
@synthesize isDataUseSSL_;
@synthesize operationQueue_;

@synthesize currentDirectory_;

-(id)init {
    self = [super init];
    
    isSessonContinue_ = NO;
    
    controlFd_ = 0;
    controlPort_ = 0;
    pLocalAddress_ = NULL;
    pRemoteAddress_ = NULL;
    
    pasvListenFd_ = -1;
    dataFd_ = -1;
    dataProgress_ = 0;
    dataPort_ = 0;
    pPortSockAddress_ = NULL;

    isAnonymous_ = YES;
    
    restartPos_ = 0;
    isAscii_ = NO;
    isEpsvAll_ = NO;
    isPasv_ = NO;
    isAbort_ = NO;
    
    reqMessage_ = nil;
    reqMessage_ = nil;
    resCode_ = 0;
    resSep_ = @" ";
    resMessage_ = nil;
    
    isControlUseSSL_ = NO;
    isDataUseSSL_ = NO;
    
    operationQueue_ = [[NSOperationQueue alloc] init];
    
    currentDirectory_ = nil;
    
    return self;
}

- (void)dealloc {
    if (pLocalAddress_ != NULL) {
        free(pLocalAddress_);
        pLocalAddress_ = NULL;
    }
    if (pPortSockAddress_ != NULL) {
        free(pPortSockAddress_);
        pPortSockAddress_ = NULL;
    }
    if (pRemoteAddress_ != NULL) {
        free(pRemoteAddress_);
        pRemoteAddress_ = NULL;
    }
    
    [operationQueue_ release];
    
    if (currentDirectory_ != nil) {
        [currentDirectory_ release];
    }
    
    [super dealloc];
}

@end
