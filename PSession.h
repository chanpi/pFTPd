//
//  PSession.h
//  pFTPd
//
//  Created by Happy on 11/01/18.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

struct Psockaddr {
    union {
        struct sockaddr u_sockaddr;
        struct sockaddr_in u_sockaddr_in;
        struct sockaddr_in6 u_sockaddr_in6;
    } u;
};

@interface PSession : NSObject {
 @private
    // Details of the Control connection
    CFSocketNativeHandle controlFd_;
    unsigned short controlPort_;
    struct Psockaddr* pLocalAddress_;
    struct Psockaddr* pRemoteAddress_;
    
    // Details of the Data connection
    CFSocketNativeHandle pasvListenFd_;
    CFSocketNativeHandle dataFd_;
    int dataProgress_;
    unsigned short dataPort_;
    struct Psockaddr* pPortSockAddress_;
    
    // Details of the login
    BOOL isAnonymous_;
    
    // Details of th FTP protocol state
    BOOL isAscii_;
    BOOL isEpsvAll_;
    BOOL isPasv_;
    
    // Request Buffers
    NSString* reqCommand_;
    NSString* reqMessage_;
    
    // Response Buffers
    int resCommand_;
    NSString* resSep_;
    NSString* resMessage_;
    
    // Control Stream
    CFReadStreamRef readStream_;
    CFWriteStreamRef writeStream_;
    
    // Secure connections state
    BOOL isControlUseSSL_;
    BOOL isDataUseSSL_;
}

@property (assign) CFSocketNativeHandle controlFd_;
@property (assign) unsigned short controlPort_;
@property (assign) struct Psockaddr* pLocalAddress_;
@property (assign) struct Psockaddr* pRemoteAddress_;

@property (assign) CFSocketNativeHandle pasvListenFd_;
@property (assign) CFSocketNativeHandle dataFd_;
@property (assign) int dataProgress_;
@property (assign) unsigned short dataPort_;
@property (assign) struct Psockaddr* pPortSockAddress_;

@property (assign) BOOL isAnonymous_;

@property (assign) BOOL isAscii_;
@property (assign) BOOL isEpsvAll_;
@property (assign) BOOL isPasv_;

@property (assign) NSString* reqCommand_;
@property (assign) NSString* reqMessage_;
@property (assign) int resCode_;
@property (assign) NSString* resSep_;
@property (assign) NSString* resMessage_;

@property (assign) CFReadStreamRef readStream_;
@property (assign) CFWriteStreamRef writeStream_;

@property (assign) BOOL isControlUseSSL_;
@property (assign) BOOL isDataUseSSL_;


@end
