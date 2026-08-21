#!/bin/sh
TARGET_DIR="/var/local/mesquite/sysmon"
DB="/var/local/appreg.db"
APP_ID="com.akshay.sysmon"
PIDFILE="${TARGET_DIR}/.stats_loop.pid"

if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$OLD_PID" ] && kill "$OLD_PID" 2>/dev/null
fi

rm -rf "$TARGET_DIR"

sqlite3 "$DB" <<EOF
DELETE FROM properties WHERE handlerId='$APP_ID';
DELETE FROM handlerIds WHERE handlerId='$APP_ID';
EOF
