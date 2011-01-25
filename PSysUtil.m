//
//  PSysUtil.m
//  pFTPd
//
//  Created by Happy on 11/01/19.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PSysUtil.h"
#import "PDefs.h"

#include <unistd.h>
#include <sys/socket.h>
#include <netinet/ip.h>
#include <sys/uio.h>

@implementation PSysUtil

- (void) dupFd2:(CFSocketNativeHandle)oldFd newFd:(CFSocketNativeHandle)newFd {
    int retVal;
    if (oldFd == newFd) {
        return;
    }
    retVal = dup2(oldFd, newFd);
    if (retVal != newFd) {
        NSLog(@"[ERROR] dupFd2:newFd:");
    }
}

- (unsigned short) sockaddrGetPort:(const struct Psockaddr*)pSockPtr {
    if (pSockPtr->u.u_sockaddr.sa_family == AF_INET) {
        return ntohs(pSockPtr->u.u_sockaddr_in.sin_port);
    } else if (pSockPtr->u.u_sockaddr.sa_family == AF_INET6) {
        return ntohs(pSockPtr->u.u_sockaddr_in6.sin6_port);
    } else {
        NSLog(@"[ERROR] bad family in sockaddrGetPort:");
    }
    // No reached
    return 0;
}

- (BOOL) sockaddrIsIPv6:(const struct sockaddr*)pSockAddress {
    if (pSockAddress == NULL) {
        NSLog(@"[ERROR] sockaddrIsIPv6: pSockAddress is NULL.");
        return NO;
    }
    if (pSockAddress->sa_family == AF_INET6) {
        return YES;
    }
    return NO;
}

- (void) getPeerName:(int)fd pSockAddrPtr:(struct Psockaddr*)pSockAddr {
    struct Psockaddr addr;
    socklen_t sockLen = sizeof(addr);
    int retval = getpeername(P_COMMAND_FD, &addr.u.u_sockaddr, &sockLen);
    if (retval != 0) {
        NSLog(@"[ERROR] getpeername");
        NSException* ex = [NSException exceptionWithName:@"PSysUtil" reason:@"getPeerName" userInfo:nil];
        @throw ex;
    }
    if (addr.u.u_sockaddr.sa_family != AF_INET && 
        addr.u.u_sockaddr.sa_family != AF_INET6) {
        NSLog(@"[ERROR] getPeerName: can only support ipv4 and ipv6 currently");
        NSException* ex = [NSException exceptionWithName:@"PSysUtil" reason:@"getPeerName: can only support ipv4 and ipv6 currently" userInfo:nil];
        @throw ex;
    }
    if (sockLen > sizeof(addr)) {
        sockLen = sizeof(addr);
    }
    
    memcpy(pSockAddr, &addr, sockLen);
}

- (void) getSockName:(int)fd pSockAddrPtr:(struct Psockaddr*)pSockAddr {
    struct Psockaddr addr;
    socklen_t sockLen = sizeof(addr);
    int retval = getsockname(fd, &addr.u.u_sockaddr, &sockLen);
    if (retval != 0) {
        NSLog(@"[ERROR] getsockname");
        NSException* ex = [NSException exceptionWithName:@"PSysUtil" reason:@"getSockName" userInfo:nil];
        @throw ex;
    }
    if (addr.u.u_sockaddr.sa_family != AF_INET && 
        addr.u.u_sockaddr.sa_family != AF_INET6) {
        NSLog(@"[ERROR] getSockName: can only support ipv4 and ipv6 currently");
        NSException* ex = [NSException exceptionWithName:@"PSysUtil" reason:@"getSockName: can only support ipv4 and ipv6 currently" userInfo:nil];
        @throw ex;
    }
    if (sockLen > sizeof(addr)) {
        sockLen = sizeof(addr);
    }
    
    memcpy(pSockAddr, &addr, sockLen);
}

- (void) activateKeepAlive:(int)fd {
    int keepAlive = 1;
    int retVal = setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &keepAlive, sizeof(keepAlive));
    if (retVal != 0) {
        NSLog(@"[ERROR] setsockopt: keepalive");
    }
}

- (void) setIptosThroughput:(int)fd {
    int tos = IPTOS_THROUGHPUT;
    setsockopt(fd, IPPROTO_IP, IP_TOS, &tos, sizeof(tos));
}

- (void) activateLinger:(int)fd {
    int retVal;
    struct linger theLinger;
    memset(&theLinger, 0x00, sizeof(theLinger));
    theLinger.l_onoff = 1;
    theLinger.l_linger = 32767;
    retVal = setsockopt(fd, SOL_SOCKET, SO_LINGER, &theLinger, sizeof(theLinger));
    if (retVal != 0) {
        NSLog(@"[ERROR] setsockopt: linger");
    }
}

- (void) deactivateLingerFailOK:(int)fd {
    struct linger theLinger;
    theLinger.l_onoff = 0;
    theLinger.l_linger = 0;
    setsockopt(fd, SOL_SOCKET, SO_LINGER, &theLinger, sizeof(theLinger));
}

- (BOOL) retValisError:(int)retVal {
    if (retVal < 0) {
        return YES;
    }
    return NO;
}

- (int) recvFd:(int)socketFd {
    /*
    int retVal;
    struct msghdr msg;
    struct iovec vec;
    char recvChar;
    int recvFd = -1;
    
    vec.iov_base = &recvChar;
    vec.iov_len = 1;
    msg.msg_name = NULL;
    msg.msg_namelen = 0;
    msg.msg_iov = &vec;
    msg.msg_iovlen = 1;
    msg.
     */
    return 0;
}

- (int) read:(const int)fd buffer:(void*)buffer size:(const size_t)size {
    int retVal;
    int savedErrno;
    
    while (1) {
        retVal = read(fd, buffer, size);
        savedErrno = errno;
        //[self checkPendingActions: :retVal :fd];  // TODO!!!!!
        NSLog(@"retVal = %d, savedErrno = %d", retVal, savedErrno);
        if (retVal < 0 && savedErrno == EINTR) {
            continue;
        }
        return retVal;
    }
}

- (int) readLoop:(const int)fd buffer:(void*)buffer size:(size_t)size {
    int retVal;
    int readLen = 0;

    while (1) {
        retVal = [self read:fd buffer:buffer size:size];
        
        if (retVal < 0) {
            NSLog(@"[ERROR] read().");
            return retVal;
        } else if (!retVal) {
            return readLen;
        }
        readLen += retVal;
        size -= retVal;
        if (size == 0) {
            return readLen;
        }
    }
}

- (int) writeLoop:(const int)fd buffer:(const void*)buffer size:(size_t)size {
    int retVal;
    int writeLen = 0;
    
    while (1) {
        retVal = write(fd, buffer + writeLen, size);
        if (retVal < 0) {
            NSLog(@"[ERROR] write().");
            return 0;
        } else if (!retVal) {
            return writeLen;
        }
        writeLen += retVal;
        size -= retVal;
        if (size == 0) {
            return writeLen;
        }
    }
}

- (int) closeFailOK:(int)fd {
    return close(fd);
}

@end
