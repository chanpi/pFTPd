//
//  PPostLogin.m
//  pFTPd
//
//  Created by Happy on 11/01/18.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PPostLogin.h"
#import "PCodes.h"
#import "PControlIO.h"
#import "PPrivilegeSocket.h"
#import "PSession.h"
#import "PDefs.h"

#include <arpa/inet.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/types.h>

@interface PPostLogin (Local)
- (void) portCleanup:(PSession*)session;
- (void) pasvCleanup:(PSession*)session;
- (unsigned short) listenPasvSocket:(PSession*)session;

- (BOOL) isPortActive:(PSession*)session;
- (BOOL) isPasvActive:(PSession*)session;
- (BOOL) dataTransferChecksOK:(PSession*)session;
- (int) getRemoteDataFd:(PSession*)session statusMessage:(NSString*)statusMessage;
- (NSUInteger)separateString:(NSString*)fromString sep:(NSString*)sepString tokens:(NSArray**)tokens;

- (BOOL) changeCurrentDirectory:(PSession*)session nextDirectory:(NSString*)nextDirectory;
- (BOOL) isChangeDirectoryEnable:(NSString*)path;
- (BOOL) isFileExist:(NSString*)path;
- (BOOL) isSymbolicLink:(NSString*)path;
- (BOOL) getRealPath:(NSString*)linkName realName:(char*)realName;
- (BOOL) isAbsolutePath:(NSString*)path;
- (NSString*) appendPathandFileName:(NSString*)path fileName:(NSString*)fileName;
- (BOOL) addOperation:(NSOperation*)operation session:(PSession*)session;
@end


@implementation PPostLogin

- (id) init {
    self = [super init];
    ctrlIO_ = [[PControlIO alloc] init];
    dataIO_ = [[PDataIO alloc] init];
    sysUtil_ = [[PSysUtil alloc] init];
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
//    session.resMessage_ = @" SIZE\r\n";
//    [ctrlIO_ writeResponseRaw:session];
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
    if (session.currentDirectory_ == nil) {
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"Failed to get current directory.";
    } else {
        session.resCode_ = FTP_PWDOK;
        session.resMessage_ = [NSString stringWithFormat:@"\"%@\"", session.currentDirectory_];
    }
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleCWD:(PSession*)session {
    if ([self changeCurrentDirectory:session nextDirectory:session.reqMessage_] == NO) {
        NSLog(@"[ERROR] changeCurrentDirectory: %@", session.currentDirectory_);
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"Failed to change directory.";
    } else {
        session.resCode_ = FTP_CWDOK;
        session.resMessage_ = @"Directory successfully changed.";
    }    
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleCDUP:(PSession*)session {
    if ([self changeCurrentDirectory:session nextDirectory:@".."] == NO) {
        NSLog(@"[ERROR] changeCurrentDirectory: %@", session.currentDirectory_);
        session.resCode_ = FTP_LOCALERROR;
        session.resMessage_ = @"Failed to change directory.";
    } else {
        session.resCode_ = FTP_CDUPOK;
        session.resMessage_ = @"Directory successfully changed.";
    }
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleMKD:(PSession*)session {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    // ファイル名のチェック
    NSString* newDirectoryName = session.reqMessage_;
    if (![self isAbsolutePath:newDirectoryName]) {
        newDirectoryName = [self appendPathandFileName:session.currentDirectory_ fileName:newDirectoryName];
    }
    if ([fileManager fileExistsAtPath:newDirectoryName]) {
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"File exist at path.";
        [ctrlIO_ sendResponseNormal:session];
        return;
    }
    
    NSError* error = nil;
    if ([fileManager createDirectoryAtPath:newDirectoryName withIntermediateDirectories:YES attributes:nil error:&error]) {
        session.resCode_ = FTP_MKDIROK;
        session.resMessage_ = [NSString stringWithFormat:@"\"%@\" created.", session.reqMessage_];
    } else {
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = [error localizedDescription];
    }    
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleRMD:(PSession*)session {
    NSFileManager* fileManeger = [NSFileManager defaultManager];
    NSError* error = nil;
    NSString* targetDirectory = session.reqMessage_;
    if (![self isAbsolutePath:targetDirectory]) {
        targetDirectory = [self appendPathandFileName:session.currentDirectory_ fileName:targetDirectory];
    }
    if ([fileManeger removeItemAtPath:targetDirectory error:&error]) {
        session.resCode_ = FTP_RMDIROK;
        session.resMessage_ = @"Remove directory operation successful.";
    } else {
        NSLog(@"[ERROR] handleRMD: %@", [error localizedDescription]);
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
    
    isIPv6 = [sysUtil_ sockaddrIsIPv6:(const struct sockaddr*)(session.pLocalAddress_)];
    
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
        char localAddress[P_IPADDRESS_LENGTH] = {0};
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
        session.resMessage_ = [NSString stringWithFormat:@"Entering Passive Mode (%@,%d,%d).",
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

- (void) handleSTAT:(PSession*)session {
    if (session.reqMessage_ == nil) {
        // stat情報を表示
        
        return;
    }
    //[self handleDirCommon:session fullDetailes:YES statCommand:YES];
}

- (void) handleLIST:(PSession*)session {
    BOOL fullDetails = YES;
    if (session.reqMessage_ != nil && [session.reqMessage_ length] > 1 && [session.reqMessage_ characterAtIndex:0] == '-') {
        NSArray* tokens = [session.reqMessage_ componentsSeparatedByString:@" "];
        if ([tokens count] > 1) {
            [session.reqMessage_ release];  // 一度allocしたものをrelease
            NSString* value = [tokens objectAtIndex:1];
            session.reqMessage_ = [[NSString alloc] initWithString:(value == nil ? @"" : value)];
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
    BOOL addOperation = NO;
    
    int error;
    NSString* dirPath = session.reqMessage_;
    
    if (dirPath == nil || [dirPath length] == 0) {
        if (session.currentDirectory_ == nil) {
            session.resCode_ = FTP_LOCALERROR;
            session.resMessage_ = @"Failed to get current directory.";
            [ctrlIO_ sendResponseNormal:session];
            return;
        } else {
            dirPath = session.currentDirectory_;
        }
    }
    
    NSMutableString* directory = [[NSMutableString alloc] init];
    [sysUtil_ getDirectoryAttributes:&directory directoryPath:dirPath];
    
    // データ接続をオープンしようとすることを知らせる
    session.resCode_ = FTP_DATACONN;
    session.resMessage_ = @"Here comes the directory listing.";
    [ctrlIO_ sendResponseNormal:session];
    
    @try {
        if (session.isPasv_) {
            struct sockaddr_in address;
            socklen_t sockLen = sizeof(address);

            session.dataFd_ = accept(session.pasvListenFd_, (struct sockaddr*)&address, &sockLen);
            [sysUtil_ activateNoSigPipe:session.dataFd_];

        } else {
            session.dataFd_ = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
            if (session.dataFd_ < 0) {
                NSLog(@"[ERROR] Failed to create data socket.");
                session.resCode_ = FTP_FILEFAIL;
                session.resMessage_ = @"Failed to create data socket.";
                
                NSException* ex = [NSException exceptionWithName:@"PException" reason:@"socket() : Failed to create data socket." userInfo:nil];
                @throw ex;
            }
            
            [sysUtil_ activateNoSigPipe:session.dataFd_];

            error = connect(session.dataFd_, (struct sockaddr*)session.pPortSockAddress_, sizeof(struct sockaddr_in));  // PORTコマンドでアドレス設定済み
            if (error < 0) {
                NSLog(@"[ERROR] Failed to connect to remote host.");
                session.resCode_ = FTP_FILEFAIL;    // TODO!!!
                session.resMessage_ = @"Failed to connect to remote host.";
                
                NSException* ex = [NSException exceptionWithName:@"PException" reason:@"connect() : Failed to connect to remote host." userInfo:nil];
                @throw ex;
            }
            
        }
        
        PDataParam* param = [[PDataParam alloc]
                             initWithSendData:[directory UTF8String] dataSize:strlen([directory UTF8String]) session:session dataFd:session.dataFd_];
        [NSThread detachNewThreadSelector:@selector(sendData:) toTarget:dataIO_ withObject:param];
        addOperation = [self addOperation:nil session:session];
                
    }
    @catch (NSException *exception) {
        NSLog(@"[ERROR] %@ communicate: %@: %@", NSStringFromClass([self class]), [exception name], [exception reason]);
        session.resCode_ = FTP_BADSENDFILE;
        session.resMessage_ = [exception reason];
    }

    if (!addOperation) {
        [ctrlIO_ sendResponseNormal:session];
        
        if (session.dataFd_ > 0) {
            close(session.dataFd_);
            session.dataFd_ = -1;
        }
    }
    
    if (session.pasvListenFd_ > 0) {
        close(session.pasvListenFd_);
        session.pasvListenFd_ = -1;
    }
    
    [directory release];
}

- (void) handleSIZE:(PSession*)session {
    /*
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSError* error;
    NSDictionary* attributes;
    NSString* filePath;
    
    if (session.currentDirectory_ == nil) {
        session.resCode_ = FTP_LOCALERROR;
        session.resMessage_ = @"Failed to get current directory.";
    } else {
        
    }
    
    char path[PATH_MAX] = {0};
    char* pwd = getcwd(path, sizeof(path));
    if (pwd == NULL) {
        session.resCode_ = FTP_LOCALERROR;
        session.resMessage_ = @"Failed to get current directory.";
    } else {
        NSString* tempFormat;
        if (path[strlen(path)-1] != '/') {
            if ([session.reqMessage_ characterAtIndex:0] != '/') {
                tempFormat = @"%@/%@";
            } else {
                tempFormat = @"%@%@";
            }
        } else {
            if ([session.reqMessage_ characterAtIndex:0] != '/') {
                tempFormat = @"%@%@";
            } else {
                tempFormat = @"%@%@";
                path[strlen(path)-1] = '\0';
            }
        }
        filePath = [NSString stringWithFormat:tempFormat, [NSString stringWithUTF8String:path], session.reqMessage_];
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
     */
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

- (void) handleABOR:(PSession*)session {
    session.isAbort_ = YES;
    
    session.resCode_ = FTP_ABOROK;
    session.resMessage_ = @"Aborted.";
    [ctrlIO_ sendResponseNormal:session];
    
    session.isAbort_ = NO;
}


- (void) handleRETR:(PSession*)session {
    NSString* filePath = session.reqMessage_;
    if (![self isAbsolutePath:filePath]) {
        filePath = [self appendPathandFileName:session.currentDirectory_ fileName:filePath];
    }
    
    NSError* error;
    unsigned long fileSize = 0;
    BOOL isDir;
    NSDictionary* attributes;
    
    NSFileHandle* fileHandle;
    int err;
    
    BOOL addOperation = NO;
    
    NSFileManager* fileManager = [NSFileManager defaultManager];

    @try {
        // ファイルが存在するか
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDir] == NO) {
            NSLog(@"[ERROR] File not found %@.", filePath);
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

            session.dataFd_ = accept(session.pasvListenFd_, (struct sockaddr*)&address, &sockLen);
            [sysUtil_ activateNoSigPipe:session.dataFd_];
            
        } else {
            session.dataFd_ = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
            if (session.dataFd_ < 0) {
                NSLog(@"[ERROR] Failed to create data socket.");
                session.resCode_ = FTP_FILEFAIL;
                session.resMessage_ = @"Failed to create data socket.";
                
                NSException* ex = [NSException exceptionWithName:@"PException" reason:@"socket() : Failed to create data socket." userInfo:nil];
                @throw ex;
            }
            
            [sysUtil_ activateNoSigPipe:session.dataFd_];

            err = connect(session.dataFd_, (struct sockaddr*)session.pPortSockAddress_, sizeof(struct sockaddr_in));
            if (err < 0) {
                NSLog(@"[ERROR] Failed to connect to remote host.");
                session.resCode_ = FTP_FILEFAIL;    // TODO!!!
                session.resMessage_ = @"Failed to connect to remote host.";
                
                NSException* ex = [NSException exceptionWithName:@"PException" reason:@"connect() : Failed to connect to remote host." userInfo:nil];
                @throw ex;
            }
        }

        PDataParam* param = [[PDataParam alloc] initWithSendFile:fileHandle fileSize:fileSize session:session dataFd:session.dataFd_];
        [NSThread detachNewThreadSelector:@selector(sendFile:) toTarget:dataIO_ withObject:param];
        addOperation = [self addOperation:nil session:session];
        
    }
    @catch (NSException *exception) {
        NSLog(@"[ERROR] %@ communicate: %@: %@", NSStringFromClass([self class]), [exception name], [exception reason]);
    }
    
    if (!addOperation) {
        if (session.dataFd_ > 0) {
            close(session.dataFd_);
            session.dataFd_ = -1;
        }
        
        [ctrlIO_ sendResponseNormal:session];
        [fileHandle closeFile];
        
    }
    
    if (session.pasvListenFd_ > 0) {
        close(session.pasvListenFd_);
        session.pasvListenFd_ = -1;
    }
}

- (void) handleSTOR:(PSession*)session {
    BOOL ret;
    BOOL addOperation = NO;
    NSFileHandle* fileHandle;
    
    // データコネクション
    if (session.isPasv_) {
        struct sockaddr_in address;
        socklen_t sockLen = sizeof(address);
        session.dataFd_ = accept(session.pasvListenFd_, (struct sockaddr*)&address, &sockLen);
        [sysUtil_ activateNoSigPipe:session.dataFd_];

    } else {
        session.dataFd_ = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (session.dataFd_ < 0) {
            NSLog(@"[ERROR] Failed to create socket() in handleSTOR.");
            session.resCode_ = FTP_BADSENDCONN;
            session.resMessage_ = @"Failed to create data socket.";
            [ctrlIO_ sendResponseNormal:session];
            return;
        }
        
        [sysUtil_ activateNoSigPipe:session.dataFd_];

        if (connect(session.dataFd_, (const struct sockaddr*)session.pPortSockAddress_, sizeof(struct sockaddr_in)) < 0) {
            NSLog(@"[ERROR] Can't open data connection.");
            session.resCode_ = FTP_BADSENDCONN;
            session.resMessage_ = @"Can't open data connection.";
            [ctrlIO_ sendResponseNormal:session];
            close(session.dataFd_);
            return;
        }
    }
      
    session.resCode_ = FTP_DATACONN;
    session.resMessage_ = @"Here comes the directory listing.";
    [ctrlIO_ sendResponseNormal:session];
    
    // ファイルを作成
    NSString* fileName = session.reqMessage_;
    if (![self isAbsolutePath:fileName]) {
        fileName = [self appendPathandFileName:session.currentDirectory_ fileName:fileName];
    }
    const char* encodedFileName = [fileName cStringUsingEncoding:NSUTF8StringEncoding];
    NSString* utf8FileName = [NSString stringWithCString:encodedFileName encoding:NSUTF8StringEncoding];
    ret = [[NSFileManager defaultManager] createFileAtPath:utf8FileName contents:nil attributes:nil];
    
    if (!ret) {
        NSLog(@"[ERROR] Failed to create file.");
        session.resCode_ = FTP_UPLOADFAIL;
        session.resMessage_ = @"Failed to create file.";
        
    } else {
        // ファイルに書き込み
        fileHandle = [NSFileHandle fileHandleForWritingAtPath:fileName];
        if (!fileHandle) {
            NSLog(@"[ERROR] Failed to open %@.", fileName);
            session.resCode_ = FTP_BADSENDFILE;
            session.resMessage_ = @"Failed to open file";
            
        } else {
            PDataParam* param = [[PDataParam alloc] initWithRecvFile:fileHandle session:session dataFd:session.dataFd_];
            [NSThread detachNewThreadSelector:@selector(recvFile:) toTarget:dataIO_ withObject:param];
            addOperation = [self addOperation:nil session:session];
        }
    }
    
    if (!addOperation) {
        [ctrlIO_ sendResponseNormal:session];
        close(session.dataFd_);
        session.dataFd_ = -1;
    }
    if (session.pasvListenFd_ > 0) {
        close(session.pasvListenFd_);
        session.pasvListenFd_ = -1;
    }
}

- (void) handleAPPE:(PSession*)session {
    BOOL addOperation = NO;
    
    NSString* fileName = session.reqMessage_;
    if (![self isAbsolutePath:fileName]) {
        fileName = [self appendPathandFileName:session.currentDirectory_ fileName:fileName];
    }
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:fileName]) {
        [self handleSTOR:session];
        return;
    }
    
    if (session.isPasv_) {
        struct sockaddr_in address;
        socklen_t sockLen = sizeof(address);
        
        session.dataFd_ = accept(session.pasvListenFd_, (struct sockaddr*)&address, &sockLen);
        
        [sysUtil_ activateNoSigPipe:session.dataFd_];

    } else {
        session.dataFd_ = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (session.dataFd_ < 0) {
            NSLog(@"[ERROR] Failed to create socket() in handleSTOR.");
            session.resCode_ = FTP_BADSENDCONN;
            session.resMessage_ = @"Failed to create data socket.";
            [ctrlIO_ sendResponseNormal:session];
            return;
        }
        
        [sysUtil_ activateNoSigPipe:session.dataFd_];
        
        if (connect(session.dataFd_, (const struct sockaddr*)session.pPortSockAddress_, sizeof(struct sockaddr_in)) < 0) {
            NSLog(@"[ERROR] Can't open data connection.");
            session.resCode_ = FTP_BADSENDCONN;
            session.resMessage_ = @"Can't open data connection.";
            [ctrlIO_ sendResponseNormal:session];
            close(session.dataFd_);
            return;
        }
    }
    
    session.resCode_ = FTP_DATACONN;
    session.resMessage_ = @"Here comes the directory listing.";
    [ctrlIO_ sendResponseNormal:session];
    
    // ファイルオープンし、追記できるようファイルポジションを進める
    NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:fileName];
    if (fileHandle == nil) {
        NSLog(@"[ERROR] Failed to open %@.", fileName);
        session.resCode_ = FTP_BADSENDFILE;
        session.resMessage_ = @"Failed to open file";
        
    } else {
        // EOFへポインタを進める
        [fileHandle seekToEndOfFile];
                
        
        PDataParam* param = [[PDataParam alloc] initWithRecvFile:fileHandle session:session dataFd:session.dataFd_];
        [NSThread detachNewThreadSelector:@selector(recvFile:) toTarget:dataIO_ withObject:param];
        addOperation = [self addOperation:nil session:session];
    }
    
    if (!addOperation) {
        [ctrlIO_ sendResponseNormal:session];
        close(session.dataFd_);
        session.dataFd_ = -1;
    }
    if (session.pasvListenFd_ > 0) {
        close(session.pasvListenFd_);
        session.pasvListenFd_ = -1;
    }

}

- (void) handleDELE:(PSession*)session {
    NSString* fileName = session.reqMessage_;
    if (![self isAbsolutePath:fileName]) {
        fileName = [self appendPathandFileName:session.currentDirectory_ fileName:fileName];
    }
    const char* encodedFileName = [fileName cStringUsingEncoding:NSUTF8StringEncoding];
    BOOL ret = [[NSFileManager defaultManager]
                removeItemAtPath:[NSString stringWithCString:encodedFileName encoding:NSUTF8StringEncoding] error:nil];
    
    if (!ret) {
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"Failed to delete file.";
        NSLog(@"[ERROR] Failed to delete file.");
    } else {
        session.resCode_ = FTP_DELEOK;
        session.resMessage_ = @"Delete file successful.";
        NSLog(@"Delete successful");
    }
    [ctrlIO_ sendResponseNormal:session];
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

- (void) handleRNFR:(PSession*)session {
    NSString* fileName = session.reqMessage_;
    if (![self isAbsolutePath:fileName]) {
        fileName = [self appendPathandFileName:session.currentDirectory_ fileName:fileName];
    }
    if ([self isFileExist:fileName]) {
        session.renameFrom_ = [fileName retain];
        session.resCode_ = FTP_RNFROK;
        session.resMessage_ = @"Please input rename to...";
    } else {
        session.resCode_ = FTP_FILEFAIL;
        session.resMessage_ = @"File not found.";
    }
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleRNTO:(PSession*)session {
    NSString* fileName = session.reqMessage_;
    NSError* error = nil;
    if (![self isAbsolutePath:fileName]) {
        fileName = [self appendPathandFileName:session.currentDirectory_ fileName:fileName];
    }
    [[NSFileManager defaultManager] moveItemAtPath:session.renameFrom_ toPath:fileName error:&error];
    if (error) {
        NSLog(@"[ERROR] handleRNTO: %@", [error localizedDescription]);
        session.resCode_ = FTP_RENAMEFAIL;
        session.resMessage_ = [error localizedDescription];
    } else {
        session.resCode_ = FTP_RNTOOK;
        session.resMessage_ = @"Rename successful.";
    }
    [ctrlIO_ sendResponseNormal:session];
    [session.renameFrom_ release];
}

- (void) handleREST:(PSession*)session {
    session.restartPos_ = [session.reqMessage_ intValue];
    if (session.restartPos_ < 0) {
        session.restartPos_ = 0;
    }
    session.resCode_ = FTP_RESTOK;
    session.resMessage_ = [NSString stringWithFormat:@"Restart position accepted (%d)", session.restartPos_];
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleQUIT:(PSession*)session {
    session.resCode_ = FTP_GOODBYE;
    session.resMessage_ = @"GoodBye";
    [ctrlIO_ sendResponseNormal:session];
}

- (void) handleNOOP:(PSession*)session {
    session.resCode_ = FTP_NOOPOK;
    session.resMessage_ = @"OK";
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
    
    [sysUtil_ activateKeepAlive:session.pasvListenFd_];
    [sysUtil_ activateNoSigPipe:session.pasvListenFd_];
    
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
    
    if ([sysUtil_ retValisError:remoteFd]) {
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
    return remoteFd;
}

- (NSUInteger)separateString:(NSString*)fromString sep:(NSString*)sepString tokens:(NSArray**)tokens {
    *tokens = [fromString componentsSeparatedByString:sepString];
    return [*tokens count];
}

- (BOOL) changeCurrentDirectory:(PSession*)session nextDirectory:(NSString*)nextDirectory {
    // CDUP
    if ([nextDirectory isEqualToString:@".."]) {
        if ([session.currentDirectory_ isEqualToString:@"/"]) {
            return YES;
        }
        
        char buffer[PATH_MAX] = {0};
        char* p = NULL;
        
        strcpy(buffer, [session.currentDirectory_ cStringUsingEncoding:NSUTF8StringEncoding]);
        if ((p = strrchr(buffer, '/')) == NULL) {
            NSLog(@"[ERROR] changeCurrentDirectory:nextDirectory:");
            return NO;
        }
        
        if (p == &buffer[0]) {
            [session.currentDirectory_ release];
            session.currentDirectory_ = [[NSString alloc] initWithString:@"/"];
        } else {
            *p = '\0';
            if ([self isChangeDirectoryEnable:[NSString stringWithUTF8String:buffer]]) {
                [session.currentDirectory_ release];
                session.currentDirectory_ = [[NSString alloc] initWithUTF8String:buffer];
            } else {
                return NO;
            }
        }
        
    // CWD
    } else {
        if (![self isAbsolutePath:nextDirectory]) {
            NSString* next = [self appendPathandFileName:session.currentDirectory_ fileName:nextDirectory];
            if ([self isSymbolicLink:next]) {
                char buffer[PATH_MAX] = {0};
                if ([self getRealPath:next realName:buffer]) {
                    next = [NSString stringWithUTF8String:buffer];
                } else {
                    return NO;
                }
            }
            
            if ([self isChangeDirectoryEnable:next]) {
                [session.currentDirectory_ release];
                session.currentDirectory_ = [next retain];
            } else {
                return NO;
            }
            
        } else {
            nextDirectory = [self appendPathandFileName:nextDirectory fileName:nil];    // 末尾の/を除去
            if ([self isSymbolicLink:nextDirectory]) {
                char buffer[PATH_MAX] = {0};
                if ([self getRealPath:nextDirectory realName:buffer]) {
                    nextDirectory = [NSString stringWithUTF8String:buffer];
                } else {
                    return NO;
                }
            }
            if ([self isChangeDirectoryEnable:nextDirectory]) {
                [session.currentDirectory_ release];
                session.currentDirectory_ = [nextDirectory retain];
            } else {
                return NO;
            }
        }
    }
    NSLog(@"#####chdir: %@", session.currentDirectory_);
    return YES;
}

- (BOOL) isChangeDirectoryEnable:(NSString*)path {
    BOOL isExist = NO;
    BOOL isDirectory = NO;
    
    isExist = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    if (!isExist || !isDirectory) {
        return NO;
    }
    return YES;
}

- (BOOL) isFileExist:(NSString*)path {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (BOOL) isSymbolicLink:(NSString*)path {
    NSError* error = nil;
    NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    if (error != nil) {
        if (errno == 1) {
            NSLog(@"[ERROR] attributesOfItemAtPath: errno = 1. Not super-user.");
        } else {
            NSLog(@"[ERROR] attributesOfItemAtPath: %@", [error localizedDescription]);
        }
        return NO;  // TODO!!
    }
    return [[attributes objectForKey:NSFileType] isEqualToString:NSFileTypeSymbolicLink];
}

- (BOOL) getRealPath:(NSString*)linkName realName:(char*)realName {
    if (realpath([linkName UTF8String], realName) == NULL) {
        if (errno == 1) {
            NSLog(@"[ERROR] realpath: errno = 1. Not super-user.");
        } else {
            NSLog(@"[ERROR] realpath: %d", errno);
        }
        return NO;
    }
    return YES;
}

// 絶対パスかどうか
- (BOOL) isAbsolutePath:(NSString*)path {
    if ([path characterAtIndex:0] == '/') {
        return YES;
    }
    return NO;
}

- (NSString*) appendPathandFileName:(NSString*)path fileName:(NSString*)fileName {
    if (path == nil) {
        if ([fileName characterAtIndex:[fileName length]-1] == '/') {
            return [fileName substringToIndex:[fileName length]-1];
        } else {
            return fileName;
        }
    }
    if (fileName == nil) {
        if (![path isEqualToString:@"/"] && [path characterAtIndex:[path length]-1] == '/') {
            return [path substringToIndex:[path length]-1];
        } else {
            return path;
        }
    }
    
    NSString* format;
    NSString* tempFileName = fileName;
    if ([fileName characterAtIndex:[fileName length]-1] == '/') {
        tempFileName = [fileName substringToIndex:[fileName length]-1];
    }
    if ([path characterAtIndex:[path length]-1] != '/') {
        if ([tempFileName characterAtIndex:0] != '/') {
            format = @"%@/%@";
        } else {
            format = @"%@%@";
        }
    } else {
        if ([tempFileName characterAtIndex:0] != '/') {
            format = @"%@%@";
        } else {
            format = @"%@%@";
            tempFileName = [tempFileName substringFromIndex:1];
        }
    }
    
    return [NSString stringWithFormat:format, path, tempFileName];
}

- (BOOL) addOperation:(NSOperation*)operation session:(PSession*)session {
//    [session.operationQueue_ addOperation:operation];
    session.dataFd_ = -1;
//    [operation release];
    return YES;
}

- (void)dealloc {
    [sysUtil_ release];
    [dataIO_ release];
    [ctrlIO_ release];
    [super dealloc];
}

@end

