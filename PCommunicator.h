//
//  PCommunicator.h
//  pFTPd
//
//  Created by Happy on 11/01/06.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSession.h"

@interface PCommunicator : NSObject {
 @private
    
}

- (void) communicate:(id)param;

- (int) getPasvFd:(PSession*)session;
- (int) getPrivDataSocket:(PSession*)session;

@end
