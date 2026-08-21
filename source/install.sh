#!/bin/sh
# Copies the app bundle into place and registers it in appreg.db — mirrors
# the same appreg pattern every mesquite/Illusion app on this device uses
# (confirmed identical across several: KAnki, KindleForge, this device's
# own dashboard app).
TARGET_DIR="/var/local/mesquite/sysmon"
DB="/var/local/appreg.db"
APP_ID="com.akshay.sysmon"

# Resolve relative to this script's own location, not the caller's cwd —
# KPM chdirs into the package dir before running install.sh, but a bare
# "./app" silently breaks if this is ever run directly from elsewhere.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

rm -rf "$TARGET_DIR"
cp -r "${SCRIPT_DIR}/app" "$TARGET_DIR"

sqlite3 "$DB" <<EOF
INSERT OR IGNORE INTO interfaces(interface) VALUES('application');
INSERT OR IGNORE INTO handlerIds(handlerId) VALUES('$APP_ID');
INSERT OR REPLACE INTO properties(handlerId,name,value)
  VALUES('$APP_ID','lipcId','$APP_ID');
INSERT OR REPLACE INTO properties(handlerId,name,value)
  VALUES('$APP_ID','command','/usr/bin/mesquite -l $APP_ID -c file://$TARGET_DIR/');
INSERT OR REPLACE INTO properties(handlerId,name,value)
  VALUES('$APP_ID','supportedOrientation','U');
EOF

echo "System Monitor installed. Launch with: kpm launch sysmon"
