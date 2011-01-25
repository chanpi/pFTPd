//
//  PMain.h
//  pFTPd
//
//  Created by Happy on 10/12/28.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PMain : NSObject {
    int commandPort_;
    int dataPort_;
}
@property (assign) int commandPort_;
@property (assign) int dataPort_;

- (BOOL) ftpdStart:(int)commandPort remote:(int)dataPort;

@end
