//
//  PDataIO.h
//  pFTPd
//
//  Created by Happy on 11/01/20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSession.h"

@interface PDataIO : NSObject {
@private
    
}

- (int) disposeTransferFd:(PSession*)session;
- (int) getPasvFd:(PSession*)session;
- (int) getPortFd:(PSession*)session;
- (BOOL) postMarkConnect:(PSession*)session;
- (unsigned long) sendData:(PSession*)session data:(const void*)data dataSize:(unsigned long)dataSize;
- (unsigned long) sendFile:(PSession*)session fileHandle:(NSFileHandle*)fileHandle fileSize:(unsigned long)fileSize;
- (unsigned long) recvFile:(PSession*)session fileHandle:(NSFileHandle*)fileHandle;

@end
