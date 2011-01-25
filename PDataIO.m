//
//  PDataIO.m
//  pFTPd
//
//  Created by Happy on 11/01/20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PDataIO.h"
#import "PCodes.h"
#import "PControlIO.h"
#import "PSysUtil.h"
#import "PCommunicator.h"
#import "PPrivilegeSocket.h"

@interface PDataIO (Local)
- (void) initDataSockParams:(PSession*)session socketFd:(int)socketFd;
@end

@implementation PDataIO

- (int) disposeTransferFd:(PSession*)session {
    PSysUtil* sysUtil = [[PSysUtil alloc] init];
    int disposeRet = 1;
    int retVal;
    if (session.dataFd_ == -1) {
        NSLog(@"[ERROR] no data descripter in disposeTransferFd:");
    }
//    [self startDataAlarm:session];
//    [sysUtil uninstallIOHandler];
    // SSLの記述
    retVal = [sysUtil closeFailOK:session.dataFd_];
    if ([sysUtil retValisError:retVal]) {
        [sysUtil deactivateLingerFailOK:session.dataFd_];
        [sysUtil closeFailOK:session.dataFd_];
    }
//    if (dataConnectionTimeout > 0) {
//        [sysUtil clearAlarm];
//    }
    session.dataFd_ = -1;
    [sysUtil release];
    return disposeRet;
}

- (int) getPasvFd:(PSession*)session {
    PCommunicator* communicator = [[PCommunicator alloc] init];
    PControlIO* ctrlIO = [[PControlIO alloc] init];
    
    int remoteFd;
    remoteFd = [communicator getPasvFd:session];
    if (remoteFd == -1) {
        session.resCode_ = FTP_BADSENDCONN;
        session.resMessage_ = @"Failed to establish connection.";
        [ctrlIO sendResponseNormal:session];
    } else if (remoteFd == -2) {
        session.resCode_ = FTP_BADSENDCONN;
        session.resMessage_ = @"Security: Bad IP connecting.";
        [ctrlIO sendResponseNormal:session];
        remoteFd = -1;
    } else {
        [self initDataSockParams:session socketFd:remoteFd];
    }
    
    [ctrlIO release];
    [communicator release];
    return remoteFd;
}

- (int) getPortFd:(PSession*)session {
    PCommunicator* communicator = [[PCommunicator alloc] init];
    PControlIO* ctrlIO = [[PControlIO alloc] init];
    PSysUtil* sysUtil = [[PSysUtil alloc] init];
    int remoteFd;
    remoteFd = [communicator getPrivDataSocket:session];
    
    if ([sysUtil retValisError:remoteFd]) {
        session.resCode_ = FTP_BADSENDCONN;
        session.resMessage_ = @"Failed to establish connection.";
        [ctrlIO sendResponseNormal:session];
        remoteFd = -1;
    }
    [self initDataSockParams:session socketFd:remoteFd];
    
    [sysUtil release];
    [ctrlIO release];
    [communicator release];
    return remoteFd;
}

// ssl未対応
- (BOOL) postMarkConnect:(PSession*)session {
    BOOL ret = NO;
//    int sockRet;
    
    if (!session.isDataUseSSL_) {
        return YES;
    }
    return ret;
//    PPrivilegeSocket* priv;
//    if (!session.sslSlaveActive) {
//        ret = sslAccept
//     }
//    priv = [[PPrivilegeSocket alloc] init];
//    [priv release];
}

- (unsigned long) sendData:(PSession*)session data:(const void*)data dataSize:(unsigned long)dataSize {
    unsigned long sendLen = 0;
    int bytes = 0;
    
    if (session.dataFd_ == -1) {
        NSLog(@"[ERROR] dataFd is not initialized.");
        return 0;
    }
    while (sendLen < dataSize) {
        bytes = send(session.dataFd_, data + sendLen, dataSize - sendLen, 0);
        if (bytes < 0) {
            NSLog(@"[ERROR] sendData()");
            session.resCode_ = FTP_BADSENDFILE;
            session.resMessage_ = @"Requested action aborted. Local error in processing : send";
            return 0;
        }
        sendLen += bytes;
    }
    return sendLen;
}

- (unsigned long) sendFile:(PSession*)session fileHandle:(NSFileHandle*)fileHandle fileSize:(unsigned long)fileSize {
    unsigned long sendLen = 0;
    int bytes = 0;
    NSData* sendData = [fileHandle readDataToEndOfFile];
    fprintf(stderr, "[%ld bytes] %s\n", fileSize, (char*)[sendData bytes]);
    
    while (sendLen < fileSize) {
        bytes = send(session.dataFd_, [sendData bytes] + sendLen, fileSize - sendLen, 0);
        if (bytes < 0) {
            // TODO!!!!!
            NSLog(@"[ERROR] sendFile:fileHandle:fileSize;");
            session.resCode_ = FTP_BADSENDFILE;
            session.resMessage_ = @"[ERROR] sendFile()";
            return 0;
        }
        sendLen += bytes;
    }
    NSLog(@"send %ld bytes", sendLen);
    session.resCode_ = FTP_TRANSFEROK;
    session.resMessage_ = @"Transfer complete. v^^v";
    return sendLen;
}

- (unsigned long) recvFile:(PSession*)session fileHandle:(NSFileHandle*)fileHandle {
    int bytes;
    unsigned long writeLen = 0;
    char recvBuffer[512] = {0};
    NSData* recvData;
    
    while (1) {
        bytes = recv(session.dataFd_, recvBuffer, sizeof(recvBuffer), 0);
        if (bytes < 0) {
            NSLog(@"[ERROR] recvFile:fileHandle:");
            return 0;
        }
        if (bytes == 0) {
            break;
        }
        recvData = [NSData dataWithBytes:recvBuffer length:bytes];
        [fileHandle writeData:recvData];
        writeLen += bytes;
    }
    
    // キャッシュとディスク上のファイルを同期する
    [fileHandle synchronizeFile];
    return writeLen;
}

- (void) initDataSockParams:(PSession*)session socketFd:(int)socketFd {
    PSysUtil* sysUtil = [[PSysUtil alloc] init];
    if (session.dataFd_ != -1) {
        NSLog(@"data descripter still present in initDataSockParams:socketFd:");
    }
    session.dataFd_ = socketFd;
    session.dataProgress_ = 0;
    [sysUtil activateKeepAlive:socketFd];
    [sysUtil activateLinger:socketFd];
    
    // start the timeout monitor
    //[sysUtil installIOHandler:handleIO session:session];
    //[self startDataAlarm:session];    // TODO!!! signalとしてタイムアウトを設定しているみたい
    [sysUtil release];
}

@end
