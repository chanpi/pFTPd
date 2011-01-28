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

@interface PSysUtil (Local)
- (void) convertFilePermissionToString:(NSString**)buffer permission:(int)permission;
- (void) convertModifiedDate:(NSString**)buffer date:(NSDate*)date;
- (void) convertModifiedTime:(NSString**)buffer date:(NSDate*)date;
@end

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


- (void) getDirectoryAttributes:(NSMutableString**)infoBuffer directoryPath:(NSString*)directoryPath {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSMutableArray* files = [[NSMutableArray alloc] initWithArray:[fileManager contentsOfDirectoryAtPath:directoryPath error:nil]];
    
    if ([directoryPath isEqualToString:@"/"] == NO) {
        [files insertObject:@"." atIndex:0];
        [files insertObject:@".." atIndex:1];
    }
    
    int count = [files count];
    NSString* filePath;
    
    //int digit = 0;  // 10進数の桁数
    //long tempWidth = 0;
    long referenceWidth = 5;
    long fileOwnerWidth = 10;
    long groupOwnerWidth = 10;
    long sizeWidth = 10;
    
    /*
    // 各項目の表示幅を決定するために事前にチェック
    for (int i = 0; i < count; i++) {
        filePath = [NSString stringWithFormat:@"%@%@", directoryPath, [files objectAtIndex:i]];
        NSLog(@"filePath = %@", filePath);
        NSDictionary* attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
        
        tempWidth = [[attributes objectForKey:NSFileReferenceCount] longValue];
        digit = 0;
        while ((tempWidth /= 10) > 0) {
            digit++;
        }
        digit++;
        if (digit > referenceWidth) {
            referenceWidth = digit;
        }
        
        tempWidth = [[attributes objectForKey:NSFileOwnerAccountName] length];
        if (tempWidth > fileOwnerWidth) {
            fileOwnerWidth = tempWidth;
        }
        
        tempWidth = [[attributes objectForKey:NSFileGroupOwnerAccountName] length];
        if (tempWidth > groupOwnerWidth) {
            groupOwnerWidth = tempWidth;
        }
        
        tempWidth = [[attributes objectForKey:NSFileSize] longValue];
        digit = 0;
        while ((tempWidth /= 10) > 0) {
            digit++;
        }
        digit++;
        if (digit > sizeWidth) {
            sizeWidth = digit;
        }
    }
    NSLog(@"refW %ld", referenceWidth);
    NSLog(@"fileOwnerWidth %ld", fileOwnerWidth);
    NSLog(@"groupOwnerWidth %ld", groupOwnerWidth);
    NSLog(@"sizeWidth %ld", sizeWidth);
    */
    
    for (int i = 0; i < count; i++) {
        /*
        if ([[files objectAtIndex:i] characterAtIndex:0] == '.') {
            continue;
        }
         */
        if ([directoryPath characterAtIndex:[directoryPath length]-1] != '/') {
            filePath = [NSString stringWithFormat:@"%@/%@", directoryPath, [files objectAtIndex:i]];
        } else {
            filePath = [NSString stringWithFormat:@"%@%@", directoryPath, [files objectAtIndex:i]];
        }
        NSDictionary* attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
        if (attributes == nil) {
            continue;
        }
        
        // ディレクトリか
        NSString* temp = [attributes objectForKey:NSFileType];
        if ([temp isEqualToString:NSFileTypeDirectory]) {
            [*infoBuffer appendString:@"d"];
        } else if ([temp isEqualToString:NSFileTypeSymbolicLink]) {
            [*infoBuffer appendString:@"l"];
        } else {
            [*infoBuffer appendString:@"-"];
        }
        
        // ファイル権限
        [self convertFilePermissionToString:&temp permission:[[attributes objectForKey:NSFilePosixPermissions] intValue]];
        [*infoBuffer appendFormat:@"%@ ", temp];
        
        // NSFileReferenceCount
        NSString* format;
        format = [NSString stringWithFormat:@"%%%ldld ", referenceWidth];    // -> @"%2ld "など
        [*infoBuffer appendFormat:format, [[attributes objectForKey:NSFileReferenceCount] longValue]];
        
        // NSFileOwnerAccountName
        temp = [attributes objectForKey:NSFileOwnerAccountName];
        [*infoBuffer appendString:temp];
        int length = [temp length];
        for (int i = length; i < fileOwnerWidth+2; i++) {
            [*infoBuffer appendString:@" "];
        }
        
        // NSFileGroupOwnerAccountName
        temp = [attributes objectForKey:NSFileGroupOwnerAccountName];
        [*infoBuffer appendString:temp];
        length = [temp length];
        for (int i = length; i < groupOwnerWidth+2; i++) {
            [*infoBuffer appendString:@" "];
        }
        
        // NSFileSize
        format = [NSString stringWithFormat:@"%%%ldld ", sizeWidth];
        [*infoBuffer appendFormat:format, [[attributes objectForKey:NSFileSize] longValue]];
        
        // 日付 (Jan 18)
        [self convertModifiedDate:&temp date:[attributes objectForKey:NSFileModificationDate]];
        [*infoBuffer appendFormat:@"%@ ", temp];
        
        // 時間 (11:15)
        [self convertModifiedTime:&temp date:[attributes objectForKey:NSFileModificationDate]];
        [*infoBuffer appendFormat:@"%@ ", temp];
        
        // FileName
        [*infoBuffer appendFormat:@"%@\r\n", [files objectAtIndex:i]];
    }
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




- (void) convertFilePermissionToString:(NSString**)buffer permission:(int)permission {
    char tempPermittion[9+1] = {0}; //user[rwx]/group[rwx]/other[rwx] +1はNSStringへのコンバート用
    tempPermittion[8] = (permission & 0x1) ? 'x' : '-', permission >>= 1;
    tempPermittion[7] = (permission & 0x1) ? 'w' : '-', permission >>= 1;
    tempPermittion[6] = (permission & 0x1) ? 'r' : '-', permission >>= 1;
    
    tempPermittion[5] = (permission & 0x1) ? 'x' : '-', permission >>= 1;
    tempPermittion[4] = (permission & 0x1) ? 'w' : '-', permission >>= 1;
    tempPermittion[3] = (permission & 0x1) ? 'r' : '-', permission >>= 1;
    
    tempPermittion[2] = (permission & 0x1) ? 'x' : '-', permission >>= 1;
    tempPermittion[1] = (permission & 0x1) ? 'w' : '-', permission >>= 1;
    tempPermittion[0] = (permission & 0x1) ? 'r' : '-';
    
    *buffer = [NSString stringWithUTF8String:tempPermittion];
}

- (void) convertModifiedDate:(NSString**)buffer date:(NSDate*)date {
    // date: "2010-11-17 09:29:18 +0000"
    NSString* format = @"MM dd";
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];
    
    *buffer = [formatter stringFromDate:date];
    [formatter release];
}

- (void) convertModifiedTime:(NSString**)buffer date:(NSDate*)date {
    NSString* format = @"HH:mm";
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];
    
    *buffer = [formatter stringFromDate:date];
    [formatter release];
}


@end
