//
//  PControlIO.m
//  pFTPd
//
//  Created by Happy on 11/01/20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PControlIO.h"

@interface PControlIO (Local)
- (unsigned long) sendResponse:(PSession*)session;
@end

@implementation PControlIO

- (int) getRequest:(PSession*)session {
    UInt8 buffer[128];
    unsigned long recvLen = 0;
    int bytes;
    size_t size = sizeof(buffer);
    
    memset(buffer, 0x00, size);
    while (!strchr((char*)buffer, '\n') && recvLen < size) {
        bytes = CFReadStreamRead(session.readStream_, buffer + recvLen, size - recvLen);
        if (bytes < 0) {
            CFErrorRef error = CFReadStreamCopyError(session.readStream_);
            CFIndex eIndex = CFErrorGetCode(error);
            CFStringRef eString = CFErrorCopyDescription(error);
            NSLog(@"[ERROR] CFReadStreamRead() %ld %@", eIndex, eString);
            session.reqCommand_ = [[NSString alloc] initWithString:@"ERROR"];
            session.reqMessage_ = [[NSString alloc] initWithString:(NSString*)eString];
            CFRelease(error);
            
            return -1;
        }
        recvLen += bytes;
    }
    
    char tempCommand[16];
    char tempValue[96];
    sscanf((const char*)buffer, "%s %s\r\n", tempCommand, tempValue);
    session.reqCommand_ = [[NSString alloc] initWithUTF8String:tempCommand];
    session.reqMessage_ = [[NSString alloc] initWithUTF8String:tempValue];
    return 0;
}


- (unsigned long) sendResponse:(PSession*)session {
    //NSString* temp = [[NSString alloc] initWithFormat:@"%d%@%@\r\n", session.resCode_, session.resSep_, session.resMessage_];
    NSString* temp = [NSString stringWithFormat:@"%d%@%@\r\n", session.resCode_, session.resSep_, session.resMessage_];
	const char* buffer = [temp UTF8String];
    unsigned long sendLen = 0;
    UInt8 count = strlen(buffer);
    int bytes;
    
    fprintf(stderr, "send: %s", buffer);
    while (sendLen < count) {
        bytes = CFWriteStreamWrite(session.writeStream_, (UInt8*)buffer + sendLen, count - sendLen);
        if (bytes < 0) {
            // TODO!!!!!
            CFErrorRef error = CFWriteStreamCopyError(session.writeStream_);
            CFIndex eIndex = CFErrorGetCode(error);
            CFStringRef eString = CFErrorCopyDescription(error);
            NSLog(@"[ERROR] CFWriteStreamWrite() %ld %@", eIndex, eString);
            CFRelease(error);
            return 0;
        }
        sendLen += bytes;
    }
    return sendLen;
}


- (unsigned long) sendResponseNormal:(PSession*)session {
    session.resSep_ = @" ";
    return [self sendResponse:session];
}


- (unsigned long) sendResponseHyphen:(PSession*)session {
    session.resSep_ = @"-";
    return [self sendResponse:session];    
}

// write message for fd 0
- (size_t) writeResponseRaw:(PSession*)session {
    /*
     char message[20];
     strcpy(message, [session.resMessage_ UTF8String]);
     size_t messageLen = [session.resMessage_ length];
     return fwrite(message, 1, messageLen, P_COMMAND_FD);
     */
    const char* buffer = [session.resMessage_ UTF8String];
    size_t sendLen = 0;
    UInt8 count = strlen(buffer);
    int bytes;
    
    while (sendLen < count) {
        bytes = CFWriteStreamWrite(session.writeStream_, (UInt8*)buffer + sendLen, count - sendLen);
        if (bytes < 0) {
            // TODO!!!!!
            CFErrorRef error = CFWriteStreamCopyError(session.writeStream_);
            CFIndex eIndex = CFErrorGetCode(error);
            CFStringRef eString = CFErrorCopyDescription(error);
            NSLog(@"[ERROR] CFWriteStreamWrite() %ld %@", eIndex, eString);
            CFRelease(error);
            return 0;
        }
        sendLen += bytes;
    }
    return sendLen;
}

@end
