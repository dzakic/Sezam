(*
 *
 *  RADIUS
 *  Remote Authentication Dial In User Service
 *
 *
 *  Livingston Enterprises, Inc.
 *  6920 Koll Center Parkway
 *  Pleasanton, CA   94566
 *
 *  Copyright 1992 Livingston Enterprises, Inc.
 *
 *  Permission to use, copy, modify, and distribute this software for any
 *  purpose and without fee is hereby granted, provided that this
 *  copyright and permission notice appear on all copies and supporting
 *  documentation, the name of Livingston Enterprises, Inc. not be used
 *  in advertising or publicity pertaining to distribution of the
 *  program without specific prior permission, and notice be given
 *  in supporting documentation that copying and distribution is by
 *  permission of Livingston Enterprises, Inc.
 *
 *  Livingston Enterprises, Inc. makes no representations about
 *  the suitability of this software for any purpose.  It is
 *  provided "as is" without express or implied warranty.
 *
 *)

Unit RadDef;

interface

const
  AUTH_VECTOR_LEN     =  16;
  AUTH_PASS_LEN       =  16;
  AUTH_STRING_LEN     = 128;  // maximum of 254

type PW_AUTH_HDR      = record
       Code           : byte;
       ID             : byte;
       Length         : SmallWord;
       Vector         : array[0..AUTH_VECTOR_LEN-1] of byte;
       Data           : array[0..1] of byte;
     end;

const
  AUTH_HDR_LEN        = 20;
  CHAP_VALUE_LENGTH   = 16;

  PW_AUTH_UDP_PORT    = 1645;
  PW_ACCT_UDP_PORT    = 1646;

  PW_TYPE_STRING      = 0;
  PW_TYPE_INTEGER     = 1;
  PW_TYPE_IPADDR      = 2;
  PW_TYPE_DATE        = 3;

  PW_AUTHENTICATION_REQUEST = 1;
  PW_AUTHENTICATION_ACK     = 2;
  PW_AUTHENTICATION_REJECT  = 3;
  PW_ACCOUNTING_REQUEST     = 4;
  PW_ACCOUNTING_RESPONSE    = 5;
  PW_ACCOUNTING_STATUS      = 6;
  PW_PASSWORD_REQUEST       = 7;
  PW_PASSWORD_ACK           = 8;
  PW_PASSWORD_REJECT        = 9;
  PW_ACCOUNTING_MESSAGE     = 10;
  PW_ACCESS_CHALLENGE       = 11;

  PW_USER_NAME              = 1;
  PW_PASSWORD               = 2;
  PW_CHAP_PASSWORD          = 3;
  PW_CLIENT_ID              = 4;
  PW_CLIENT_PORT_ID         = 5;
  PW_USER_SERVICE_TYPE      = 6;
  PW_FRAMED_PROTOCOL        = 7;
  PW_FRAMED_ADDRESS         = 8;
  PW_FRAMED_NETMASK         = 9;
  PW_FRAMED_ROUTING         = 10;
  PW_FRAMED_FILTER_ID       = 11;
  PW_FRAMED_MTU             = 12;
  PW_FRAMED_COMPRESSION     = 13;
  PW_LOGIN_HOST             = 14;
  PW_LOGIN_SERVICE          = 15;
  PW_LOGIN_TCP_PORT         = 16;
  PW_OLD_PASSWORD           = 17;
  PW_PORT_MESSAGE           = 18;
  PW_DIALBACK_NO            = 19;
  PW_DIALBACK_NAME          = 20;
  PW_EXPIRATION             = 21;
  PW_FRAMED_ROUTE           = 22;
  PW_FRAMED_IPXNET          = 23;
  PW_STATE                  = 24;

  PW_ACCT_STATUS_TYPE       = 40;
  PW_ACCT_DELAY_TIME        = 41;
  PW_ACCT_INPUT_OCTETS      = 42;
  PW_ACCT_OUTPUT_OCTETS     = 43;
  PW_ACCT_SESSION_ID        = 44;
  PW_ACCT_AUTHENTIC         = 45;
  PW_ACCT_SESSION_TIME      = 46;

// INTEGER TRANSLATIONS
// USER TYPES

  PW_LOGIN_USER             = 1;
  PW_FRAMED_USER            = 2;
  PW_DIALBACK_LOGIN_USER    = 3;
  PW_DIALBACK_FRAMED_USER   = 4;

// FRAMED PROTOCOLS

  PW_PPP                    = 1;
  PW_SLIP                   = 2;

// FRAMED ROUTING VALUES

  PW_NONE                   = 0;
  PW_BROADCAST              = 1;
  PW_LISTEN                 = 2;
  PW_BROADCAST_LISTEN       = 3;

// FRAMED COMPRESSION TYPES

  PW_VAN_JACOBSEN_TCP_IP    = 1;

// LOGIN SERVICES

  PW_TELNET                 = 0;
  PW_RLOGIN                 = 1;
  PW_TCP_CLEAR              = 2;
  PW_PORTMASTER             = 3;

// AUTHENTICATION LEVEL

  PW_AUTH_NONE              = 0;
  PW_AUTH_RADIUS            = 1;
  PW_AUTH_LOCAL             = 2;

// STATUS TYPES

  PW_STATUS_START           = 1;
  PW_STATUS_STOP            = 2;
  PW_STATUS_ALIVE           = 3;

// Default Database File Names
(*
  RADIUS_DIR      "/mptn/etc/raddb"
  RADACCT_DIR     "/mptn/etc/radacct"

  RADIUS_DICTIONARY "dictionary"
  RADIUS_CLIENTS    "clients"
  RADIUS_USERS    "users"
  RADIUS_HOLD   "holdusers"
  RADIUS_LOG    "logfile"
*)

// Server data structures

type PDictAttr              = ^DictAttr;
     DictAttr               = record
       name                 : string[32];
       Value                : integer;
       Typ                  : integer;
       Next                 : PDictAttr;
     end;

     PDictValue             = ^DictValue;
     DictValue              = record
       AttrName             : string[32];
       Value                : integer;
       Next                 : PDictValue;
     end;

     PValuePair             = ^ValuePair;
     ValuePair              = record
       name                 : string[32];
       Attr                 : integer;
       Typ                  : integer;
       Value                : word;
       StrValue             : string[AUTH_STRING_LEN];
       Next                 : PValuePair;
     end;

     PAuthReq               = ^AuthReq;
     AuthReq                = record
       IPAddr               : integer;
       UdpPort              : smallword;
       ID                   : byte;
       Code                 : byte;
       Vector               : array[0..AUTH_VECTOR_LEN-1] of byte;
       Secret               : array[0..AUTH_PASS_LEN-1] of byte;
       Request              : ^ValuePair;
       ChildPid             : integer;
       TimeStamp            : integer;
       Next                 : PAuthReq;
     end;

const

  SECONDS_PER_DAY   = 86400;
  MAX_REQUEST_TIME  = 30;
  CLEANUP_DELAY     = 5;
  MAX_REQUESTS      = 100;

//  AUTH_HDR : PW_AUTH_HDR;

implementation

end.
