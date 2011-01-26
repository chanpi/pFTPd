//
//  PPostLogin.h
//  pFTPd
//
//  Created by Happy on 11/01/18.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSession.h"
#import "PControlIO.h"
#import "PDataIO.h"

@interface PPostLogin : NSObject {
@private
    PControlIO* ctrlIO_;
    PDataIO* dataIO_;
}

- (void) handleSYST:(PSession*)session;
- (void) handleFEAT:(PSession*)session;
- (void) handlePWD:(PSession*)session;
- (void) handleCWD:(PSession*)session;
- (void) handleCDUP:(PSession*)session;
- (void) handleMKD:(PSession*)session;
- (void) handleRMD:(PSession*)session;

- (void) handlePASV:(PSession*)session isEPSV:(BOOL)isEPSV;
- (void) handleTYPE:(PSession*)session;
- (void) handleLIST:(PSession*)session;
- (void) handleNLIST:(PSession*)session;
- (void) handleDirCommon:(PSession *)session fullDetailes:(BOOL)fullDetailes statCommand:(BOOL)statCommand;

- (void) handleSIZE:(PSession*)session;
- (void) handlePORT:(PSession*)session;
- (void) handleRETR:(PSession*)session;

- (void) handleSTOR:(PSession*)session;

- (void) handleQUIT:(PSession*)session;
- (void) handleHELP:(PSession*)session;
- (void) handleNOOP:(PSession*)session;
- (void) handleUNKNOWN:(PSession*)session;

@end
