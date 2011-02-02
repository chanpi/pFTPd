//
//  PDataIO.h
//  pFTPd
//
//  Created by Happy on 11/01/20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSession.h"

// 
@interface PDataParam : NSObject {
@private
    CFSocketNativeHandle dataFd_;
    
    PSession* session_;
    NSFileHandle* fileHandle_;
    unsigned long long dataSize_;
    void* data_;
}

- (id) initWithSendData:(const void*)data dataSize:(unsigned long long)dataSize session:(PSession*)session dataFd:(CFSocketNativeHandle)dataFd;
- (id) initWithSendFile:(NSFileHandle*)fileHandle fileSize:(unsigned long long)fileSize session:(PSession*)session dataFd:(CFSocketNativeHandle)dataFd;
- (id) initWithRecvFile:(NSFileHandle*)fileHandle session:(PSession*)session dataFd:(CFSocketNativeHandle)dataFd;

@property (assign) CFSocketNativeHandle dataFd_;
@property (assign) PSession* session_;
@property (assign) NSFileHandle* fileHandle_;
@property (assign) unsigned long long dataSize_;
@property (assign) void* data_;

@end




@interface PDataIO : NSObject {
@private
    
}

- (int) disposeTransferFd:(PSession*)session;
- (int) getPasvFd:(PSession*)session;
- (int) getPortFd:(PSession*)session;
- (BOOL) postMarkConnect:(PSession*)session;
//- (unsigned long long) sendData:(PSession*)session data:(const void*)data dataSize:(unsigned long long)dataSize;
//- (unsigned long long) sendFile:(PSession*)session fileHandle:(NSFileHandle*)fileHandle fileSize:(unsigned long long)fileSize;
//- (unsigned long long) recvFile:(PSession*)session fileHandle:(NSFileHandle*)fileHandle;

// スレッドで動作させる
- (void) sendData:(id)param;
- (void) sendFile:(id)param;
- (void) recvFile:(id)param;

@end
