//
//  PPostLogin.m
//  pFTPd
//
//  Created by Happy on 11/01/18.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PPostLogin.h"
#import "PCodes.h"
#import "PSysUtil.h"
#import "PControlIO.h"
#import "PPrivilegeSocket.h"

#include <arpa/inet.h>
#include <unistd.h>
#include <sys/stat.h>

@interface PPostLogin (Local)
- (void) portCleanup:(PSession*)session;
- (void) pasvCleanup:(PSession*)session;
- (unsigned short) listenPasvSocket:(PSession*)session;

- (BOOL) isPortActive:(PSession*)session;
- (BOOL) isPasvActive:(PSession*)session;
- (BOOL) dataTransferChecksOK:(PSession*)session;
- (int) getRemoteDataFd:(PSession*)session statusMessage:(NSString*)statusMessage;
- (NSUInteger)separateString:(NSString*)fromString sep:(NSString*)sepString tokens:(NSArray**)tokens;
@end


@implementation PPostLogin

- (id) init {
    self = [super init];
    ctrlIO_ = [[PControlIO alloc] init];
    dataIO_ = [[PDataIO alloc] init];
    return self;
}

- (void) handleSYST:(PSession*)session {
    session.resCode_ = FTP_SYSTOK;
    session.resMessage_ = @"UNIX Type: L8";
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleFEAT:(PSession*)session {
    session.resCode_ = FTP_FEAT;
    session.resMessage_ = @"Features:";
    [ctrlIO_ sendResponseHyphen:session];
    
    /*
    if (sslEnable) {
        session.resMessage_ = @" AUTH SSL\r\n";
        [ctrlIO_ writeResponseRaw:session];
        session.resMessage_ = @" AUTH TLS\r\n";
        [ctrlIO_ writeResponseRaw:session];
    }
     */
    
//    if (portEnable) {
        session.resMessage_ = @" EPRT\r\n";
        [ctrlIO_ writeResponseRaw:session];
//    }
    
//    if (pasvEnable) {
        session.resMessage_ = @" EPSV\r\n";
        [ctrlIO_ writeResponseRaw:session];
//    }
    
    session.resMessage_ = @" MDTM\r\n";
    [ctrlIO_ writeResponseRaw:session];
    
//    if (pasvEnable) {
        session.resMessage_ = @" PASV\r\n";
        [ctrlIO_ writeResponseRaw:session];
//    }
    
    /*
    if (sslEnable) {
        session.resMessage_ = @" PBSZ\r\n";
        [ctrlIO_ writeResponseRaw:session];
        session.resMessage_ = @" PROT\r\n";
        [ctrlIO_ writeResponseRaw:session];
    }
     */
    session.resMessage_ = @" REST STREAM\r\n";
    [ctrlIO_ writeResponseRaw:session];
    session.resMessage_ = @" SIZE\r\n";
    [ctrlIO_ writeResponseRaw:session];
    session.resMessage_ = @" TVFS\r\n";
    [ctrlIO_ writeResponseRaw:session];
    session.resMessage_ = @" UTF8\r\n";
    [ctrlIO_ writeResponseRaw:session];
    
    session.resCode_ = FTP_FEAT;
    session.resMessage_ = @"End";
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handlePWD:(PSession*)session {
    char path[256];
    char* pwd = getcwd(path, sizeof(path));
    if (pwd != NULL) {
        session.resMessage_ = [NSString stringWithUTF8String:path];
    } else {
        session.resMessage_ = @"/";
    }
    session.resCode_ = FTP_PWDOK;
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleCWD:(PSession*)session {
    if (chdir([session.reqMessage_ UTF8String]) == 0) {
        session.resCode_ = FTP_CWDOK;
        session.resMessage_ = @"Directory successfully changed.";
    } else {
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"Failed to change directory.";
    }
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleCDUP:(PSession*)session {
    session.reqMessage_ = @"..";
    [self handleCWD:session];
}

- (void) handleMKD:(PSession*)session {
    mode_t mode = S_IRUSR | S_IWUSR | S_IXUSR |
                    S_IRGRP | S_IWGRP | S_IXGRP |
                    S_IROTH | S_IWOTH | S_IXOTH;
    if (mkdir([session.reqMessage_ UTF8String], mode) == 0) {
        session.resCode_ = FTP_MKDIROK;
        session.resMessage_ = [NSString stringWithFormat:@"\"%@\" created.", session.reqMessage_];
    } else {
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"Create directory operation failed.";
    }
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleRMD:(PSession*)session {
    if (rmdir([session.reqMessage_ UTF8String]) == 0) {
        session.resCode_ = FTP_RMDIROK;
        session.resMessage_ = @"Remove directory operation successful.";
    } else {
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"Remove directory operation failed.";
    }
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handlePASV:(PSession*)session isEPSV:(BOOL)isEPSV {
    unsigned short pasvPort;
    BOOL isIPv6;
    if (session.pLocalAddress_ == NULL) {   // TODO!!!!
        session.resCode_ = FTP_GOODBYE;
        session.resMessage_ = @"Server Error. (EPSV)";
        [ctrlIO_ sendResponseNormal:session];
        return;
    }
    isIPv6 = [[[PSysUtil alloc] init] sockaddrIsIPv6:(const struct sockaddr*)(session.pLocalAddress_)];
    
    if (isEPSV && [session.reqMessage_ length] != 0) {
        int argval;
        [session.reqMessage_ uppercaseString];
        if ([session.reqMessage_ isEqualToString:@"ALL"]) {
            session.isEpsvAll_ = YES;
            session.resCode_ = FTP_EPSVALLOK;
            session.resMessage_ = @"EPSV All OK.";
            [ctrlIO_ sendResponseNormal:session];
            return;
        }
        
        argval = [session.reqMessage_ intValue];
        if (argval < 1 || argval > 2 || (!isIPv6 && argval == 2)) {
            session.resCode_ = FTP_EPSVBAD;
            session.resMessage_ = @"Bad network protocol.";
            [ctrlIO_ sendResponseNormal:session];
            return;
        }
    }
    
    [self pasvCleanup:session];
    [self portCleanup:session];
    
    [self listenPasvSocket:session];
    
    if (isEPSV) {
        session.resCode_ = FTP_EPSVOK;
        session.resMessage_ = [NSString stringWithFormat:@"Entering Extended Passive Mode (|||%ld|).", (unsigned long)pasvPort];
        [ctrlIO_ sendResponseNormal:session];
        return;
    }

    // TODO
}

- (void) handleTYPE:(PSession*)session {
    [session.reqMessage_ uppercaseString];
    
    session.resCode_ = FTP_TYPEOK;
    if ([session.reqMessage_ isEqualToString:@"I"] ||
        [session.reqMessage_ isEqualToString:@"L8"] ||
        [session.reqMessage_ isEqualToString:@"L 8"]) {
        session.isAscii_ = NO;
        session.resMessage_ = @"Switching to Binary mode.";
    } else if ([session.reqMessage_ isEqualToString:@"A"] ||
               [session.reqMessage_ isEqualToString:@"A N"]) {
        session.isAscii_ = YES;
        session.resMessage_ = @"Switching to ASCII mode.";
    } else {
        session.resCode_ = FTP_BADCMD;
        session.resMessage_ = @"Unrecognized TYPE command.";
    }
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleLIST:(PSession*)session {
    [self handleDirCommon:session fullDetailes:YES statCommand:NO];
}

- (void) handleNLIST:(PSession*)session {
    if (session.reqMessage_ != nil) {
        [self handleDirCommon:session fullDetailes:YES statCommand:NO];
    } else {
        [self handleDirCommon:session fullDetailes:NO statCommand:NO];
    }
}

- (void) handleDirCommon:(PSession *)session fullDetailes:(BOOL)fullDetailes statCommand:(BOOL)statCommand {
    char commandBuffer[512];
    FILE* fp;
    int error;
    char lscommand[12];
    if (fullDetailes) {
        if (session.reqMessage_ == nil) {
            strcpy(lscommand, "ls -l");
        } else {
            sprintf(lscommand, "ls %s", [session.reqMessage_ UTF8String]);
        }
    } else {
        strcpy(lscommand, "ls");
    }
    
    if ((fp = popen(lscommand, "r")) == NULL) {
        NSLog(@"[ERROR] popen()");
        session.resCode_ = FTP_BADSENDFILE;
        session.resMessage_ = @"Requested action aborted. Local error in processing : popen";
        [ctrlIO_ sendResponseNormal:session];
        return;
    }
    
    // リモートアドレスの設定
    session.dataFd_ = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (session.dataFd_ < 0) {
        NSLog(@"[ERROR] Failed to create socket() in handleDirCommon.");
        session.resCode_ = FTP_BADSENDCONN;
        session.resMessage_ = @"Failed to create data socket.";
        [ctrlIO_ sendResponseNormal:session];
        return;
    }
    
    // データ接続をオープンしようとすることを知らせる
    session.resCode_ = FTP_DATACONN;
    session.resMessage_ = @"Here comes the directory listing.";
    [ctrlIO_ sendResponseNormal:session];
    
    error = connect(session.dataFd_, (const struct sockaddr*)session.pPortSockAddress_, sizeof(struct sockaddr_in));
    if (error < 0) {
        NSLog(@"[ERROR] Can't open data connection.");
        session.resCode_ = FTP_BADSENDCONN;
        session.resMessage_ = @"Can't open data connection.";
        [ctrlIO_ sendResponseNormal:session];
        return;
    }
    
    while (1) {
        memset(commandBuffer, 0x00, sizeof(commandBuffer));
        fgets(commandBuffer, sizeof(commandBuffer), fp);
        if (feof(fp)) {
            session.resCode_ = FTP_TRANSFEROK;
            session.resMessage_ = @"Directory send OK.";
            [ctrlIO_ sendResponseNormal:session];
            break;
        }
        if ([dataIO_ sendData:session data:commandBuffer dataSize:strlen(commandBuffer)] == 0) {
            break;
        }
    }
    pclose(fp);
    close(session.dataFd_);
}

- (void) handleSIZE:(PSession*)session {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSError* error;
    NSDictionary* attributes;
    NSString* filePath;
    
    char path[256];
    char* pwd = getcwd(path, sizeof(path));
    if (pwd == NULL) {
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"Could not get file size.";
    } else {
        filePath = [NSString stringWithFormat:@"%@%@", [NSString stringWithUTF8String:path], session.reqMessage_];
        NSLog(@"File Path : %@", filePath);
        
        // ファイル情報
        attributes = [fileManager attributesOfItemAtPath:filePath error:&error];
        // ファイルタイプ属性
        if ([attributes objectForKey:NSFileType] != NSFileTypeRegular) {
            session.resCode_ = FTP_FILEFAIL;
            session.resMessage_ = @"Could not get file size.";
        } else {
            session.resCode_ = FTP_SIZEOK;
            session.resMessage_ = [NSString stringWithFormat:@"%ld", [[attributes objectForKey:@"NSFileSize"] longValue]];
        }
    }
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handlePORT:(PSession*)session {
    NSArray* portTokens;
    NSString* remoteIP;
    ushort thePort = 0;
    char portBuffer[2][4];
    NSUInteger tokenCount = [self separateString:session.reqMessage_ sep:@"," tokens:&portTokens];
    if (tokenCount != 6) {
        NSLog(@"[ERROR] Failed to get port number.");
        session.resCode_ = FTP_BADCMD;
        session.resMessage_ = @"Illegal PORT command.";
        [ctrlIO_ sendResponseNormal:session];
        return;
    }
    
    NSString* temp = [portTokens objectAtIndex:4];
    strcpy(portBuffer[0], [temp UTF8String]);

    temp = [portTokens objectAtIndex:5];
    strcpy(portBuffer[1], [temp UTF8String]);
    
    thePort = atoi(portBuffer[0])<<8;
    thePort |= atoi(portBuffer[1]);
    
    remoteIP = [NSString stringWithFormat:@"%@.%@.%@.%@",
                [portTokens objectAtIndex:0],
                [portTokens objectAtIndex:1],
                [portTokens objectAtIndex:2],
                [portTokens objectAtIndex:3]];
    NSLog(@"Client data address/port : %@:%d", remoteIP, thePort);
    
    if (session.pPortSockAddress_ == NULL) {
        session.pPortSockAddress_ = (struct Psockaddr*)malloc(sizeof(struct Psockaddr));
    }
    
    //memcpy(session.pPortSockAddress_, session.pLocalAddress_, sizeof(struct Psockaddr));
    session.pPortSockAddress_->u.u_sockaddr_in. sin_addr.s_addr = inet_addr([remoteIP UTF8String]);
    session.pPortSockAddress_->u.u_sockaddr_in.sin_port = htons(thePort);
    session.pPortSockAddress_->u.u_sockaddr_in.sin_family = AF_INET;
    if (session.pPortSockAddress_->u.u_sockaddr_in.sin_addr.s_addr == 0xffffffff) {
        NSLog(@"[ERROR] inet_addr!!!!!!!!!!!!!!!!");
    }
    // TODO
    // 
    
    session.resCode_ = FTP_PORTOK;
    session.resMessage_ = @"PORT command successful. Consider using PASV.";
    [ctrlIO_ sendResponseNormal:session];
}


- (void) handleRETR:(PSession*)session {
    NSLog(@"Required file is %@", session.reqMessage_);

    NSString* filePath = session.reqMessage_;   // TODO!! 絶対パス
    NSError* error;
    unsigned long fileSize = 0;
    BOOL isDir;
    NSDictionary* attributes;
    
    NSFileHandle* fileHandle;
    int err;
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    @try {
        // ファイルが存在するか
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDir] == NO) {
            NSLog(@"[ERROR] File not found %@.", session.reqMessage_);
            session.resCode_ = FTP_FILEFAIL;
            session.resMessage_ = @"File not found";
            [ctrlIO_ sendResponseNormal:session];
            return;
        }
        // ファイルか
        if (isDir) {
            NSLog(@"[ERROR] File is Directory.");
            session.resCode_ = FTP_FILEFAIL;
            session.resMessage_ = @"File is Directory.";
            [ctrlIO_ sendResponseNormal:session];
            return;
        }
        // TODO アクセス権
        
        // ファイル情報
        attributes = [fileManager attributesOfItemAtPath:filePath error:&error];
        // ファイルサイズ
        fileSize = [[attributes objectForKey:@"NSFileSize"] longValue];    
        
        // ファイルオープン
        fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
        if (fileHandle == nil) {
            NSLog(@"[ERROR] Open File %@.", filePath);
            session.resCode_ = FTP_FILEFAIL;
            session.resMessage_ = @"Failed to open file.";
            [ctrlIO_ sendResponseNormal:session];
            return;
        }
        
        session.resCode_ = FTP_DATACONN;
        session.resMessage_ = [NSString stringWithFormat:@"Opening %@ mode data connection for %@ (%ld bytes).",
                               session.isAscii_ ? @"Ascii" : @"Binary", session.reqMessage_, fileSize];  // TODO!!! handle_retr
        [ctrlIO_ sendResponseNormal:session];
        
        session.dataFd_ = 0;
        session.dataFd_ = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (session.dataFd_ < 0) {
            NSLog(@"[ERROR] Failed to create data socket.");
            session.resCode_ = FTP_FILEFAIL;
            session.resMessage_ = @"Failed to create data socket.";
            
            NSException* ex = [NSException exceptionWithName:@"PException" reason:@"socket() : Failed to create data socket." userInfo:nil];
            @throw ex;
        }
        
        err = connect(session.dataFd_, (struct sockaddr*)session.pPortSockAddress_, sizeof(struct sockaddr_in));
        if (err < 0) {
            NSLog(@"[ERROR] Failed to connect to remote host.");
            session.resCode_ = FTP_FILEFAIL;    // TODO!!!
            session.resMessage_ = @"Failed to connect to remote host.";
            
            NSException* ex = [NSException exceptionWithName:@"PException" reason:@"connect() : Failed to connect to remote host." userInfo:nil];
            @throw ex;
        }
        
        [dataIO_ sendFile:session fileHandle:fileHandle fileSize:fileSize];
        
    }
    @catch (NSException *exception) {
        NSLog(@"[ERROR] %@ communicate: %@: %@", NSStringFromClass([self class]), [exception name], [exception reason]);
    }

    if (session.dataFd_ != 0) {
        close(session.dataFd_);
        session.dataFd_ = 0;
    }
    
    [ctrlIO_ sendResponseNormal:session];
    [fileHandle closeFile];
    
    if (session.pPortSockAddress_ != NULL) {
        free(session.pPortSockAddress_);
        session.pPortSockAddress_ = NULL;
    }
}

- (void) handleSTOR:(PSession*)session {
    BOOL ret;
    NSFileHandle* fileHandle;
    
    session.dataFd_ = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (session.dataFd_ < 0) {
        NSLog(@"[ERROR] Failed to create socket() in handleSTOR.");
        session.resCode_ = FTP_BADSENDCONN;
        session.resMessage_ = @"Failed to create data socket.";
        [ctrlIO_ sendResponseNormal:session];
        return;
    }

    if (connect(session.dataFd_, (const struct sockaddr*)session.pPortSockAddress_, sizeof(struct sockaddr_in)) < 0) {
        NSLog(@"[ERROR] Can't open data connection.");
        session.resCode_ = FTP_BADSENDCONN;
        session.resMessage_ = @"Can't open data connection.";
        [ctrlIO_ sendResponseNormal:session];
        close(session.dataFd_);
        return;
    }
        
    session.resCode_ = FTP_DATACONN;
    session.resMessage_ = @"Here comes the directory listing.";
    [ctrlIO_ sendResponseNormal:session];
    
    ret = [[NSFileManager defaultManager] createFileAtPath:session.reqMessage_ contents:nil attributes:nil];
    if (!ret) {
        NSLog(@"[ERROR] Failed to create file.");
        session.resCode_ = FTP_UPLOADFAIL;
        session.resMessage_ = @"Failed to create file.";
        
    } else {
        fileHandle = [NSFileHandle fileHandleForWritingAtPath:session.reqMessage_];
        if (!fileHandle) {
            NSLog(@"[ERROR] Failed to open %@.", session.reqMessage_);
            session.resCode_ = FTP_BADSENDFILE;
            session.resMessage_ = @"Failed to open file";
            
        } else {
            if (![dataIO_ recvFile:session fileHandle:fileHandle]) {
                NSLog(@"[ERROR] Failed to write file.");
                session.resCode_ = FTP_BADSENDFILE;
                session.resMessage_ = @"Failed to write file.";
            }
            [fileHandle closeFile];
        }
    }
    
    [ctrlIO_ sendResponseNormal:session];
    close(session.dataFd_);
}

- (void) handleHELP:(PSession*)session {
    session.resCode_ = FTP_HELP;
    session.resMessage_ = @"The following commands are recognized.";
    [ctrlIO_ sendResponseHyphen:session];
    
    session.resMessage_ = @" ABOR ACCT ALLO APPE CDUP CWD DELE EPRT EPSV FEAT HELP LIST MDTM MKD\r\n";
    [ctrlIO_ writeResponseRaw:session];
    session.resMessage_ = @" MODE NLST NOOP OPTS PASS PASV PORT PWD QUIT REIN REST RETR RMD  RNFR\r\n";
    [ctrlIO_ writeResponseRaw:session];
    session.resMessage_ = @" RNTO SITE SIZE SMNT STAT STOR STOU STRU SYST TYPE USER XCUP XCWD XMKD\r\n";
    [ctrlIO_ writeResponseRaw:session];
    session.resMessage_ = @" XPWD XRMD\r\n";
    [ctrlIO_ writeResponseRaw:session];
    
    session.resCode_ = FTP_HELP;
    session.resMessage_ = @"Help OK.";
    [ctrlIO_ sendResponseHyphen:session];    
}

- (void) handleQUIT:(PSession*)session {
    session.resCode_ = FTP_GOODBYE;
    session.resMessage_ = @"GoodBye";
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleUNKNOWN:(PSession*)session {
    session.resCode_ = FTP_GOODBYE;
    session.resMessage_ = [NSString stringWithFormat:@"[Unsupported] %@", session.reqCommand_];
    [ctrlIO_ sendResponseNormal:session];
}

// static >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

- (void) portCleanup:(PSession*)session {
    if (session.pPortSockAddress_ != NULL) {
        free(session.pPortSockAddress_);
        session.pPortSockAddress_ = NULL;
    }
}

- (void) pasvCleanup:(PSession*)session {
    PPrivilegeSocket* privSock = [[PPrivilegeSocket alloc] init];
    char res;
    [privSock sendCommand:session.controlFd_ command:PRIV_SOCK_PASV_CLEANUP];
    res = [privSock getResult:session.controlFd_];
    if (res != PRIV_SOCK_RESULT_OK) {
        NSLog(@"[ERROR] could not clean up socket.");
    }
    [privSock release];
}

- (unsigned short) listenPasvSocket:(PSession*)session {
    PPrivilegeSocket* privSock = [[PPrivilegeSocket alloc] init];
    unsigned short listenPort = 0;
    [privSock sendCommand:session.controlFd_ command:PRIV_SOCK_PASV_LISTEN];
    listenPort = (unsigned short)[privSock getInt:session.controlFd_];
    [privSock release];
    
    return listenPort;
}

- (BOOL) isPortActive:(PSession*)session {
    PPrivilegeSocket* privSock = [[PPrivilegeSocket alloc] init];
    BOOL ret = NO;
    if (session.pPortSockAddress_ != NULL) {
        ret = YES;
        if ([self isPasvActive:session]) {
            NSLog(@"[ERROR] port and pasv both active.");
            session.resMessage_ = @"port and pasv both active.";
        }
    }
    [privSock release];
    return ret;
}

- (BOOL) isPasvActive:(PSession*)session {
    PPrivilegeSocket* privSock = [[PPrivilegeSocket alloc] init];
    int retVal;
    [privSock sendCommand:session.controlFd_ command:PRIV_SOCK_PASV_ACTIVE];
    retVal = [privSock getInt:session.controlFd_];
    [privSock release];
    return retVal;
}

- (BOOL) dataTransferChecksOK:(PSession*)session {
    if (![self isPasvActive:session] && ![self isPortActive:session]) {
        session.resCode_ = FTP_BADSENDCONN;
        session.resMessage_ = @"Use PORT or PASV first.";
        [ctrlIO_ sendResponseNormal:session];
        return NO;
    }
    
    // TODO
    // anonymousとsslのチェック
    return YES;
}

- (int) getRemoteDataFd:(PSession*)session statusMessage:(NSString*)statusMessage {
    PSysUtil* sysUtil;
    int remoteFd;
    if (![self isPasvActive:session] && ![self isPortActive:session]) {
        NSLog(@"neither PORT nor PASV active in getRemoteDataFd:statusMessage:");
        return -1;
    }
    if ([self isPasvActive:session]) {
        remoteFd = [dataIO_ getPasvFd:session];
    } else {
        remoteFd = [dataIO_ getPortFd:session];
    }
    
    sysUtil = [[PSysUtil alloc] init];
    if ([sysUtil retValisError:remoteFd]) {
        remoteFd = -1;
    } else  {
        session.resCode_ = FTP_DATACONN;
        session.resMessage_ = statusMessage;
        [ctrlIO_ sendResponseNormal:session];
    
        if ([dataIO_ postMarkConnect:session] != 1) {
            [dataIO_ disposeTransferFd:session];
            remoteFd = -1;
        }
    }
    [sysUtil release];
    return remoteFd;
}

- (NSUInteger)separateString:(NSString*)fromString sep:(NSString*)sepString tokens:(NSArray**)tokens {
    *tokens = [fromString componentsSeparatedByString:sepString];
    return [*tokens count];
}

- (void)dealloc {
    [dataIO_ release];
    [ctrlIO_ release];
    [super dealloc];
}

@end

