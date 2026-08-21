#!/bin/sh
# Starts the background stats-refresh loop and opens the app. Doesn't
# touch the installed files — that's install.sh's job (KPM runs install.sh
# once at install/upgrade time, launch.sh on every launch).
TARGET_DIR="/var/local/mesquite/sysmon"
APP_ID="com.akshay.sysmon"
PIDFILE="${TARGET_DIR}/.stats_loop.pid"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Not installed — run: kpm install sysmon"
    exit 1
fi

# Stop any previous loop before starting a new one, so relaunching doesn't
# stack up duplicate writers.
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$OLD_PID" ] && kill "$OLD_PID" 2>/dev/null
fi

# Bounded to ~20 minutes (300 * 4s) so it can't become an orphaned
# forever-process if the app is closed by navigating away rather than a
# clean shutdown signal we could otherwise catch.
(
    i=0
    while [ "$i" -lt 300 ]; do
        sh "${TARGET_DIR}/generate_stats.sh" "${TARGET_DIR}/status.json"
        sleep 4
        i=$((i + 1))
    done
) &
echo $! > "$PIDFILE"

nohup lipc-set-prop com.lab126.appmgrd start app://$APP_ID >/dev/null 2>&1 &
