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
#import "PSession.h"

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
    /*
    
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
     */
    
    /*
    if (sslEnable) {
        session.resMessage_ = @" PBSZ\r\n";
        [ctrlIO_ writeResponseRaw:session];
        session.resMessage_ = @" PROT\r\n";
        [ctrlIO_ writeResponseRaw:session];
    }
     */
    /*
    session.resMessage_ = @" REST STREAM\r\n";
    [ctrlIO_ writeResponseRaw:session];
     */
    session.resMessage_ = @" SIZE\r\n";
    [ctrlIO_ writeResponseRaw:session];
    /*
    session.resMessage_ = @" TVFS\r\n";
    [ctrlIO_ writeResponseRaw:session];
    session.resMessage_ = @" UTF8\r\n";
    [ctrlIO_ writeResponseRaw:session];
     */
    
    session.resCode_ = FTP_FEAT;
    session.resMessage_ = @"End";
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handlePWD:(PSession*)session {
    char path[256];
    char* pwd = getcwd(path, sizeof(path));
    if (pwd != NULL) {
        session.resMessage_ = [NSString stringWithFormat:@"\"%@\"", [NSString stringWithUTF8String:path]];
    } else {
        NSLog(@"getcwd = NULL!!!");
        session.resMessage_ = @"\"/\"";
    }
    session.resCode_ = FTP_PWDOK;
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleCWD:(PSession*)session {
    if (chdir([session.reqMessage_ UTF8String]) == 0) {
        session.resCode_ = FTP_CWDOK;
        session.resMessage_ = @"Directory successfully changed.";
    } else {
        NSLog(@"[ERROR] chdir");
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"Failed to change directory.";
    }
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleCDUP:(PSession*)session {
    [session.reqMessage_ release];  // 元々allocされているので一度releaseしている
    session.reqMessage_ = [[NSString alloc] initWithString:@".."];
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
    
    PSysUtil* sysUtil = [[PSysUtil alloc] init];
    isIPv6 = [sysUtil sockaddrIsIPv6:(const struct sockaddr*)(session.pLocalAddress_)];
    [sysUtil release];
    
    if (isEPSV && [session.reqMessage_ length] != 0) {
        int argval;
        [session.reqMessage_ uppercaseString];
        if ([session.reqMessage_ isEqualToString:@"ALL"]) {
            session.isEpsvAll_ = YES;
            session.resCode_ = FTP_EPSVALLOK;
            session.resMessage_ = @"EPSV All OK.";
            [ctrlIO_ sendResponseNormal:session];
            //session.isPasv_ = YES;
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
    
    //[self pasvCleanup:session];
    //[self portCleanup:session];
    
    pasvPort = [self listenPasvSocket:session]; // create pasv socket. bind & listen.
    if (pasvPort == 0) {    // ERROR
        return;
    }
    
    if (isEPSV) {
        session.resCode_ = FTP_EPSVOK;
        session.resMessage_ = [NSString stringWithFormat:@"Entering Extended Passive Mode (|||%ld|).", (unsigned long)pasvPort];
        [ctrlIO_ sendResponseNormal:session];
        return;
    } else {
        char localAddress[20] = {0};
        char* p = localAddress;
        struct in_addr inAddr;
        inAddr = session.pLocalAddress_->u.u_sockaddr_in.sin_addr;
        strcpy(localAddress, inet_ntoa(inAddr));
        while (*p != '\0') {
            if (*p == '.') {
                *p = ',';
            }
            p++;
        }
        
        session.isPasv_ = YES;
        
        session.resCode_ = FTP_PASVOK;
        session.resMessage_ = [NSString stringWithFormat:@"Entering Passive Mode. %@,%d,%d",
                               [NSString stringWithUTF8String:localAddress], 0xff & pasvPort>>8, 0xff & pasvPort];
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
    BOOL fullDetails = YES;
    if (session.reqMessage_ != nil && [session.reqMessage_ length] > 1 && [session.reqMessage_ characterAtIndex:0] == '-') {
        NSArray* tokens = [session.reqMessage_ componentsSeparatedByString:@" "];
        if ([tokens count] > 1) {
            [session.reqMessage_ release];  // 一度allocしたものをrelease
            session.reqMessage_ = [[NSString alloc] initWithString:[tokens objectAtIndex:1]];
        } else {
            [session.reqMessage_ release];  // 一度allocしたものをrelease
            session.reqMessage_ = [[NSString alloc] initWithString:@""];
        }
    }
    [self handleDirCommon:session fullDetailes:fullDetails statCommand:NO];
}

- (void) handleNLIST:(PSession*)session {
    if (session.reqMessage_ != nil) {
        [self handleDirCommon:session fullDetailes:YES statCommand:NO];
    } else {
        [self handleDirCommon:session fullDetailes:NO statCommand:NO];
    }
}

- (void) handleDirCommon:(PSession *)session fullDetailes:(BOOL)fullDetailes statCommand:(BOOL)statCommand {
    socklen_t sockLength = 0;
    NSString* dirPath = session.reqMessage_;
    if (dirPath == nil || [dirPath length] == 0) {
        char currentDirectory[32];
        if (getcwd(currentDirectory, sizeof(currentDirectory)) != NULL) {
            dirPath = [NSString stringWithUTF8String:currentDirectory];
        } else {
            session.resCode_ = FTP_BADSENDFILE;
            session.resMessage_ = @"Failed to get current directory.";
            [ctrlIO_ sendResponseNormal:session];
            return;
        }
    }
    
    NSLog(@"currentDir = %@[%d]", dirPath, [dirPath length]);
    
    NSMutableString* directory = [[NSMutableString alloc] init];
    PSysUtil* sysUtil = [[PSysUtil alloc] init];
    [sysUtil getDirectoryAttributes:&directory directoryPath:dirPath];
    NSLog(@"%@", directory);
    [sysUtil release];
    
    // データ接続をオープンしようとすることを知らせる
    session.resCode_ = FTP_DATACONN;
    session.resMessage_ = @"Here comes the directory listing.";
    [ctrlIO_ sendResponseNormal:session];
    
    if (session.pPortSockAddress_ == NULL) {
        session.pPortSockAddress_ = (struct Psockaddr*)malloc(sizeof(struct Psockaddr));
    }
    sockLength = sizeof(struct sockaddr);
    session.dataFd_ = accept(session.pasvListenFd_, (struct sockaddr*)session.pPortSockAddress_, &sockLength);
    NSLog(@"accepted!!!!");
    
    [dataIO_ sendData:session data:[directory UTF8String] dataSize:[directory length]];
    session.resCode_ = FTP_TRANSFEROK;
    session.resMessage_ = @"Directory send OK.";
    [ctrlIO_ sendResponseNormal:session];
    
    close(session.dataFd_);
    close(session.pasvListenFd_);
    session.dataFd_ = session.pasvListenFd_ = -1;
    
    [directory release];
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
    
    session.isPasv_ = NO;
    
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
        
        if (session.isPasv_) {
            struct sockaddr_in address;
            socklen_t sockLen = sizeof(address);

            session.dataFd_ = accept(session.pasvListenFd_, (struct sockeaddr*)&address, &sockLen);
            [dataIO_ sendFile:session fileHandle:fileHandle fileSize:fileSize];
            
        } else {
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
        
    }
    @catch (NSException *exception) {
        NSLog(@"[ERROR] %@ communicate: %@: %@", NSStringFromClass([self class]), [exception name], [exception reason]);
    }

    if (session.dataFd_ > 0) {
        close(session.dataFd_);
        session.dataFd_ = -1;
    }
    if (session.pasvListenFd_ > 0) {
        close(session.pasvListenFd_);
        session.pasvListenFd_ = -1;
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

- (void) handleNOOP:(PSession*)session {
    session.resCode_ = FTP_NOOPOK;
    session.resMessage_ = @"Ok";
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleUNKNOWN:(PSession*)session {
    session.resCode_ = FTP_COMMANDNOTIMPL;
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
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_port = 0;    // TODO 0
    address.sin_addr.s_addr = INADDR_ANY;
    
    session.pasvListenFd_ = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (session.pasvListenFd_ <= 0) {
        NSLog(@"[ERROR] Failed to create pasv socket.");
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"Failed to pasv socket.";
        [ctrlIO_ sendResponseNormal:session];

        return 0;
    }
    if (bind(session.pasvListenFd_, (const struct sockaddr*)&address, sizeof(struct sockaddr)) < 0) {
        NSLog(@"[ERROR] Failed to bind pasv socket.");
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"Failed to bind pasv socket.";
        [ctrlIO_ sendResponseNormal:session];
        return 0;
    }
    if (listen(session.pasvListenFd_, 1) < 0) {
        NSLog(@"[ERROR] Failed to listen pasv socket.");
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"Failed to listen pasv socket.";
        [ctrlIO_ sendResponseNormal:session];
        return 0;
    }
    
    
    struct sockaddr_in pasvAddr;
    socklen_t pasvLen = sizeof(pasvAddr);
    if (getsockname(session.pasvListenFd_, (struct sockaddr*)&pasvAddr, &pasvLen) == 0) {
        fprintf(stderr, "[PASVPORT] %d (%d)\n", ntohs(address.sin_port), ntohs(pasvAddr.sin_port));
        return ntohs(pasvAddr.sin_port);
    }
    return ntohs(address.sin_port);
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

