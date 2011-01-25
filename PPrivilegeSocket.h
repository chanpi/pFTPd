//
//  PPrivilegeSocket.h
//  pFTPd
//
//  Created by Happy on 11/01/20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSysUtil.h"

#define PRIV_SOCK_LOGIN             1
#define PRIV_SOCK_CHOWN             2
#define PRIV_SOCK_GET_DATA_SOCK     3
#define PRIV_SOCK_GET_USER_CMD      4
#define PRIV_SOCK_WRITE_USER_RESP   5
#define PRIV_SOCK_DO_SSL_HANDSHAKE  6
#define PRIV_SOCK_DO_SSL_CLOSE      7
#define PRIV_SOCK_DO_SSL_READ       8
#define PRIV_SOCK_DO_SSL_WRITE      9
#define PRIV_SOCK_PASV_CLEANUP      10
#define PRIV_SOCK_PASV_ACTIVE       11
#define PRIV_SOCK_PASV_LISTEN       12
#define PRIV_SOCK_PASV_ACCEPT       13

#define PRIV_SOCK_RESULT_OK         1
#define PRIV_SOCK_RESULT_BAD        2

@interface PPrivilegeSocket : NSObject {
@private
    PSysUtil* sysUtil_;
}

- (int) recvFd:(int)fd;
- (char) getResult:(int)fd;
- (int) getInt:(int)fd;

- (void) sendInt:(int)fd theInt:(int)theInt;
- (void) sendCommand:(int)fd command:(char)command;

@end
