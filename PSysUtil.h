//
//  PSysUtil.h
//  pFTPd
//
//  Created by Happy on 11/01/19.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSession.h"

@interface PSysUtil : NSObject {
@private
    
}

- (void) dupFd2:(CFSocketNativeHandle)oldFd newFd:(CFSocketNativeHandle)newFd;

- (unsigned short) sockaddrGetPort:(const struct Psockaddr*)pSockPtr;
- (BOOL) sockaddrIsIPv6:(const struct sockaddr*)pSockAddress;

- (void) getDirectoryAttributes:(NSMutableString**)infoBuffer directoryPath:(NSString*)directoryPath;
- (void) getPeerName:(int)fd pSockAddrPtr:(struct Psockaddr*)pSockAddr;
- (void) getSockName:(int)fd pSockAddrPtr:(struct Psockaddr*)pSockAddr;
- (void) activateKeepAlive:(int)fd;
- (void) setIptosThroughput:(int)fd;

- (void) activateLinger:(int)fd;
- (void) deactivateLingerFailOK:(int)fd;

- (BOOL) retValisError:(int)retVal;

- (int) recvFd:(int)socketFd;
- (int) read:(const int)fd buffer:(void*)buffer size:(const size_t)size;
- (int) readLoop:(const int)fd buffer:(void*)buffer size:(size_t)size;
- (int) writeLoop:(const int)fd buffer:(const void*)buffer size:(size_t)size;
- (int) closeFailOK:(int)fd;

@end
