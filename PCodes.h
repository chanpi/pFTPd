//
//  PCodes.h
//  pFTPd
//
//  Created by Happy on 11/01/07.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#ifndef P_FTPCODES_H
#define P_FTPCODES_H

#define FTP_DATACONN        150

#define FTP_PORTOK          200
#define FTP_TYPEOK          200
#define FTP_EPSVALLOK       200
#define FTP_FEAT            211
#define FTP_STATOK          211
#define FTP_SIZEOK          213
#define FTP_HELP            214
#define FTP_SYSTOK          215
#define FTP_GREET           220
#define FTP_GOODBYE         221
#define FTP_TRANSFEROK      226
#define FTP_PASVOK          227
#define FTP_EPSVOK          229
#define FTP_LOGINOK         230
#define FTP_CWDOK           250
#define FTP_RMDIROK         250
#define FTP_PWDOK           257
#define FTP_MKDIROK         257

#define FTP_GIVEPWORD       331

#define FTP_BADSENDCONN     425
#define FTP_BADSENDNET      426
#define FTP_BADSENDFILE     451

#define FTP_BADCMD          500
#define FTP_COMMANDNOTIMPL  502
#define FTP_EPSVBAD         522
#define FTP_DATATLSBAD      522
#define FTP_FILEFAIL        550
#define FTP_NOPENM          550
#define FTP_UPLOADFAIL      553

#endif /* P_FTPCODES_H */
