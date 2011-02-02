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
#import "PDefs.h"

#include <sys/select.h>
#include <unistd.h>

@implementation PDataParam

@synthesize dataFd_;
@synthesize session_;
@synthesize fileHandle_;
@synthesize dataSize_;
@synthesize data_;

- (id) init {
    self = [super init];
    self.dataFd_ = 0;
    self.session_ = nil;
    self.fileHandle_ = nil;
    self.dataSize_ = 0;
    self.data_ = NULL;
    return self;
}

- (id) initWithSendData:(const void*)data dataSize:(unsigned long long)dataSize session:(PSession*)session dataFd:(CFSocketNativeHandle)dataFd {
    self = [super init];
    
    self.data_ = malloc(dataSize);
    memcpy(self.data_, data, dataSize);
    
    self.dataSize_ = dataSize;
    self.session_ = session;
    self.dataFd_ = dataFd;
    self.fileHandle_ = nil;
    
    return self;
}

- (id) initWithSendFile:(NSFileHandle*)fileHandle fileSize:(unsigned long long)fileSize session:(PSession*)session dataFd:(CFSocketNativeHandle)dataFd {
    self = [super init];
    
    self.data_ = NULL;
    self.dataSize_ = fileSize;
    self.session_ = session;
    self.dataFd_ = dataFd;
    self.fileHandle_ = fileHandle;
    
    return self;
}

- (id) initWithRecvFile:(NSFileHandle*)fileHandle session:(PSession*)session dataFd:(CFSocketNativeHandle)dataFd {
    self = [super init];
    
    self.data_ = NULL;
    self.dataSize_ = 0;
    self.session_ = session;
    self.dataFd_ = dataFd;
    self.fileHandle_ = fileHandle;
    
    return self;
}

- (void) dealloc {
    if (self.data_ != NULL) {
        free(self.data_);
    }
    [super dealloc];
}

@end

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

//- (unsigned long long) sendData:(PSession*)session data:(const void*)data dataSize:(unsigned long long)dataSize {
- (void) sendData:(id)param {
    PSession* session = ((PDataParam*)param).session_;
    CFSocketNativeHandle dataFd = ((PDataParam*)param).dataFd_;
    const void* data = ((PDataParam*)param).data_;
    unsigned long long dataSize = ((PDataParam*)param).dataSize_;
    PControlIO* ctrlIO = [[PControlIO alloc] init];
        
    unsigned long long sendLen = 0;
    int bytes = 0;
    
    @try {
        if (dataFd == -1) {
            NSLog(@"[ERROR] dataFd is not initialized.");
            return;
        }
        while (sendLen < dataSize && !session.isAbort_) {
            bytes = send(dataFd, data + sendLen, dataSize - sendLen, SO_NOSIGPIPE);
            if (bytes < 0) {
                @synchronized(session) {
                    if (errno == EPIPE) {
                        NSLog(@"[ERROR] SIGPIPE!!!");
                        session.resCode_ = FTP_BADSENDFILE;
                        session.resMessage_ = @"Connection is closed.";
                    } else {            
                        NSLog(@"[ERROR] sendData()");
                        session.resCode_ = FTP_BADSENDFILE;
                        session.resMessage_ = @"Requested action aborted. Local error in processing : send";
                    }
                    [ctrlIO sendResponseNormal:session];                    
                }
                
                NSException* ex = [NSException exceptionWithName:@"PException" reason:@"send() : send error." userInfo:nil];
                @throw ex;
            }
            sendLen += bytes;
        }
        
        @synchronized(session) {
            if (sendLen < dataSize && session.isAbort_) {
                session.resCode_ = FTP_BADSENDNET;
                session.resMessage_ = @"Transfer aborted.";
            } else if (sendLen == dataSize) {
                session.resCode_ = FTP_TRANSFEROK;
                session.resMessage_ = @"Directory send OK.";
            } else {
                session.resCode_ = FTP_BADSENDFILE;
                session.resMessage_ = @"Failed to list up files.";
            }
            [ctrlIO sendResponseNormal:session];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[ERROR] %@ recvFile: %@: %@", NSStringFromClass([self class]), [exception name], [exception reason]);
    }
    @finally {
        close(dataFd);
        
        [ctrlIO release];
        [param release];
    }
}

//- (unsigned long long) sendFile:(PSession*)session fileHandle:(NSFileHandle*)fileHandle fileSize:(unsigned long long)fileSize {
- (void) sendFile:(id)param {
    PSession* session = ((PDataParam*)param).session_;
    CFSocketNativeHandle dataFd = ((PDataParam*)param).dataFd_;
    NSFileHandle* fileHandle = ((PDataParam*)param).fileHandle_;
    unsigned long long fileSize = ((PDataParam*)param).dataSize_;
    PControlIO* ctrlIO = [[PControlIO alloc] init];
    
    unsigned long long sendLen = 0, totalSendLen = 0;
    unsigned long long leftFileSize;
    int bytes = 0;
    NSData* sendData;
    
    @try {
        while (totalSendLen < fileSize && !session.isAbort_) {
            
            if (fileSize - totalSendLen > P_READ_FILE_SIZE) {
                leftFileSize = P_READ_FILE_SIZE;
            } else {
                leftFileSize = fileSize - totalSendLen;
            }
            
            sendData = [fileHandle readDataOfLength:leftFileSize];
            [fileHandle seekToFileOffset:leftFileSize];
            
            while (sendLen < leftFileSize && !session.isAbort_) {
                bytes = send(dataFd, [sendData bytes] + sendLen, leftFileSize - sendLen, SO_NOSIGPIPE);
                if (bytes < 0) {
                    
                    @synchronized(session) {
                        if (errno == EPIPE) {
                            NSLog(@"[ERROR] SIGPIPE!!");
                            session.resCode_ = FTP_BADSENDFILE;
                            session.resMessage_ = @"Connection is closed.";
                        } else {
                            NSLog(@"[ERROR] sendFile:fileHandle:fileSize; errno = %d", errno);
                            session.resCode_ = FTP_BADSENDFILE;
                            session.resMessage_ = @"Failed to transfer file.";
                        }
                        [ctrlIO sendResponseNormal:session];
                    }
                    
                    NSException* ex = [NSException exceptionWithName:@"PException" reason:@"send() : send error." userInfo:nil];
                    @throw ex;
                }
                sendLen += bytes;
            }
            
            totalSendLen += sendLen;
            sendLen = 0;
        }
        
        @synchronized(session) {
            if (session.isAbort_) {
                if (totalSendLen < fileSize) {
                    session.resCode_ = FTP_BADSENDNET;
                    session.resMessage_ = @"Transfer aborted.";
                }
            } else {
                NSLog(@"send %lld bytes", totalSendLen);
                session.resCode_ = FTP_TRANSFEROK;
                session.resMessage_ = @"Transfer complete. v^^v";
            }
            [ctrlIO sendResponseNormal:session];
            
            /*
            // TODO !!!! malloc する意味はあるのか？？？
            if (session.pPortSockAddress_ != NULL) {
                free(session.pPortSockAddress_);
                session.pPortSockAddress_ = NULL;
            }
             */
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[ERROR] %@ recvFile: %@: %@", NSStringFromClass([self class]), [exception name], [exception reason]);
    }
    @finally {
        [fileHandle closeFile];
        close(dataFd);
        
        [ctrlIO release];
        [param release];
    }
}

//- (unsigned long long) recvFile:(PSession*)session fileHandle:(NSFileHandle*)fileHandle {
- (void) recvFile:(id)param {
    PSession* session = ((PDataParam*)param).session_;
    CFSocketNativeHandle dataFd = ((PDataParam*)param).dataFd_;
    NSFileHandle* fileHandle = ((PDataParam*)param).fileHandle_;
    PControlIO* ctrlIO = [[PControlIO alloc] init];
    
    int bytes;
    unsigned long long writeLen = 0;
    char recvBuffer[P_READ_FILE_SIZE] = {0};
    NSData* recvData;
    
    struct timeval timeVal;
    fd_set fdset;
    
    @try {
        while (!session.isAbort_) {
            FD_ZERO(&fdset);
            FD_SET(dataFd, &fdset);
            
            timeVal.tv_sec = 1;
            timeVal.tv_usec = 0;
            
            int ret = select((int)(dataFd)+1, &fdset, NULL, NULL, &timeVal);
            if (ret == 0) {
                // timeout
                continue;
            } else if (ret == -1) {
                NSLog(@"[ERROR] Failed to recv data.");
                
                @synchronized(session) {
                    session.resCode_ = FTP_BADSENDFILE;
                    session.resMessage_ = @"Failed to recv data.";
                    [ctrlIO sendResponseNormal:session];
                }
                
                NSException* ex = [NSException exceptionWithName:@"PException" reason:@"select() : select error." userInfo:nil];
                @throw ex;
            }
            
            bytes = recv(dataFd, recvBuffer, sizeof(recvBuffer), SO_NOSIGPIPE);
            if (bytes < 0) {
                @synchronized(session) {
                    if (errno == EPIPE) {
                        NSLog(@"[ERROR] SIGPIPE!!");
                        session.resCode_ = FTP_BADSENDFILE;
                        session.resMessage_ = @"Connection is closed.";
                    } else {
                        NSLog(@"[ERROR] Failed to write file.");
                        session.resCode_ = FTP_BADSENDFILE;
                        session.resMessage_ = @"Failed to write file.";
                    }
                    [ctrlIO sendResponseNormal:session];
                }
                
                NSException* ex = [NSException exceptionWithName:@"PException" reason:@"recv() : recv error." userInfo:nil];
                @throw ex;
            }
            if (bytes == 0) {
                break;
            }
            recvData = [[NSData alloc] initWithBytes:recvBuffer length:bytes];
            [fileHandle writeData:recvData];
            writeLen += bytes;
            
            // キャッシュとディスク上のファイルを同期する
            [fileHandle synchronizeFile];
            
            [recvData release];
        }
        
        // キャッシュとディスク上のファイルを同期する
        [fileHandle synchronizeFile];
        
        @synchronized(session) {
            if (!session.isAbort_) {
                session.resCode_ = FTP_BADSENDNET;
                session.resMessage_ = @"Transfer aborted.";
            } else {
                session.resCode_ = FTP_TRANSFEROK;
                session.resMessage_ = @"Transfer file successful.";
            }
            [ctrlIO sendResponseNormal:session];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[ERROR] %@ recvFile: %@: %@", NSStringFromClass([self class]), [exception name], [exception reason]);
    }
    @finally {
        [fileHandle closeFile];
        close(dataFd);
        
        [ctrlIO release];
        [param release];
    }
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
