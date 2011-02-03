//
//  PControlIO.m
//  pFTPd
//
//  Created by Happy on 11/01/20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PControlIO.h"
#include <unistd.h>

@interface PControlIO (Local)
- (int) sendResponse:(PSession*)session;
- (NSString*) removeWhiteSpace:(NSString*)string;
@end

@implementation PControlIO

- (int) getRequest:(PSession*)session {
    UInt8 buffer[512] = {0};
    unsigned long recvLen = 0;
    int bytes;
    size_t size = sizeof(buffer);
    
    while (!strchr((char*)buffer, '\n') && recvLen < size && session.isSessonContinue_) {
        bytes = recv(session.controlFd_, buffer+recvLen, size-recvLen, 0);
        if (bytes < 0) {
            fprintf(stderr, "[ERROR] recv: %d\n", errno);
            session.reqCommand_ = [[NSString alloc] initWithString:@"ERROR"];
            session.reqMessage_ = [[NSString alloc] initWithString:@"recv error"];
            return -1;
        }
        recvLen += bytes;
    }
    
    char tempCommand[16] = {0};
    char tempValue[512] = {0};
    char* p = NULL;
	
	fprintf(stderr, ">>> %s\n", (char*)buffer);
    sscanf((const char*)buffer, "%s ", tempCommand);
    if (strlen(tempCommand) == 0) {
        return -2;
    }
    
    if ((p = strchr((const char*)buffer, ' ')) != NULL) {
        strcpy(tempValue, p+1);
    }
    
    session.reqCommand_ = [[NSString alloc] initWithUTF8String:tempCommand];
	if (strlen(tempValue) != 0) {
		NSString* value = [NSString stringWithUTF8String:tempValue];
		if (value == nil) {
			value = [NSString stringWithCString:tempValue encoding:NSShiftJISStringEncoding];
		}
        value = [self removeWhiteSpace:value];
		session.reqMessage_ = [[NSString alloc] initWithString:(value == nil ? @"" : value)];
	} else {
		session.reqMessage_ = [[NSString alloc] initWithString:@""];
	}

    return 0;
}

- (int) sendResponse:(PSession*)session {
    NSString* temp = [NSString stringWithFormat:@"%d%@%@\r\n", session.resCode_, session.resSep_, session.resMessage_];
	const char* buffer = [temp UTF8String];
    unsigned long sendLen = 0;
    UInt8 count = strlen(buffer);
    int bytes;
    
    while (sendLen < count && session.isSessonContinue_) {
        bytes = send(session.controlFd_, buffer+sendLen, count-sendLen, 0);
        if (bytes < 0) {
            fprintf(stderr, "[ERROR] send: %d\n", errno);
            return -1;
        }
        sendLen += bytes;
    }
    fprintf(stderr, "sent: %s", buffer);
    return sendLen;
}


- (int) sendResponseNormal:(PSession*)session {
    session.resSep_ = @" ";
    return [self sendResponse:session];
}


- (int) sendResponseHyphen:(PSession*)session {
    session.resSep_ = @"-";
    return [self sendResponse:session];    
}

// write message for fd 0
- (size_t) writeResponseRaw:(PSession*)session {
    const char* buffer = [session.resMessage_ UTF8String];
    size_t sendLen = 0;
    UInt8 count = strlen(buffer);
    int bytes;
    
    while (sendLen < count && session.isSessonContinue_) {
        bytes = send(session.controlFd_, buffer+sendLen, count-sendLen, 0);
        if (bytes < 0) {
            fprintf(stderr, "[ERROR] send: %d\n", errno);
            return -1;
        }
        sendLen += bytes;
    }
    return sendLen;
}

- (NSString*) removeWhiteSpace:(NSString*)string {
    NSCharacterSet* charset = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSLog(@"removeWhiteSpace:[%@]", [string stringByTrimmingCharactersInSet:charset]);
    return [string stringByTrimmingCharactersInSet:charset];
}

@end
