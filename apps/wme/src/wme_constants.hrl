%%% WM-E protocol constants (subset for v1: handshake + config read).

-define(WME_H1, 16#1B).
-define(WME_H2, 16#16).

%% Commands
-define(CMD_START_READ, 16#67).
-define(CMD_READ_HDR,   16#68).
-define(CMD_READ_PKT,   16#70).
-define(CMD_READ_RSP,   16#71).

-define(CMD_SYSLOG_READ, 16#50).
-define(CMD_SYSLOG_HDR,  16#51).

%% Syslog read IDs (plan §9.1)
-define(SYSLOG_ID_DEVICE, 16#10).
-define(SYSLOG_ID_USER,   16#11).

%% Read option bytes
-define(OPT_CONFIG, 16#FF).
-define(OPT_STATUS, 16#0A).  %% WM_E_STATUS_READ (legacy docs also list 16#0D)
-define(OPT_METER,  16#0B).

%% Chunk sizes
-define(CHUNK_V1, 256).
-define(CHUNK_V2, 1024).

%% IEC identification (Phase A)
-define(IEC_PROBE, <<"/?99999999!\r\n">>).
-define(IEC_ACK,   <<16#06, "059\r\n">>).

%% Device error prefix (e.g. 15 45 32 = E2)
-define(WME_DEVICE_ERR, 16#15).
