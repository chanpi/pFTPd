//
//  PPreLogin.h
//  pFTPd
//
//  Created by Happy on 11/01/20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSession.h"
#import "PControlIO.h"

@interface PPreLogin : NSObject {
 @private
    PControlIO* ctrlIO_;
}

- (void) startLogin:(PSession*)session;
- (void) handleUSER:(PSession*)session;
- (BOOL) handlePASS:(PSession*)session;

@end
