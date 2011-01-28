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

@synthesize pasvListenFd_;
@synthesize dataFd_;
@synthesize dataProgress_;
@synthesize dataPort_;
@synthesize pPortSockAddress_;

@synthesize isAnonymous_;

@synthesize isAscii_;
@synthesize isEpsvAll_;
@synthesize isPasv_;

@synthesize reqCommand_;
@synthesize reqMessage_;
@synthesize resCode_;
@synthesize resSep_;
@synthesize resMessage_;

@synthesize readStream_;
@synthesize writeStream_;

@synthesize isControlUseSSL_;
@synthesize isDataUseSSL_;

-(id)init {
    self = [super init];
    
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
    
    isAscii_ = NO;
    isEpsvAll_ = NO;
    isPasv_ = NO;
    
    reqMessage_ = nil;
    reqMessage_ = nil;
    resCode_ = 0;
    resSep_ = @" ";
    resMessage_ = nil;
    
    readStream_ = NULL;
    writeStream_ = NULL;
    
    isControlUseSSL_ = NO;
    isDataUseSSL_ = NO;
    
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
    [super dealloc];
}

@end
