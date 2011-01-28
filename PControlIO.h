//
//  PControlIO.h
//  pFTPd
//
//  Created by Happy on 11/01/20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSession.h"

@interface PControlIO : NSObject {
@private
    
}

- (int) getRequest:(PSession*)session;
- (int) sendResponseNormal:(PSession*)session;
- (int) sendResponseHyphen:(PSession*)session;
- (size_t) writeResponseRaw:(PSession*)session;

@end
