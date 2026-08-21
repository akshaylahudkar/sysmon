#!/bin/sh
# Writes current battery/RAM/CPU stats as JSON to the path given as $1.
# Called in a loop by launch.sh, not meant to be run once-off for a UI —
# see that script for the polling/timeout setup.
OUT="$1"

# ── Battery — same auto-detect approach as the standalone battery-health
# tool: don't hardcode a PMIC name (varies by Kindle generation).
BATDIR=""
for d in /sys/class/power_supply/*/; do
    if [ -f "${d}type" ] && [ "$(cat "${d}type" 2>/dev/null)" = "Battery" ]; then
        BATDIR="$d"
        break
    fi
done

read_or_null() {
    if [ -n "$BATDIR" ] && [ -f "${BATDIR}$1" ]; then cat "${BATDIR}$1"; else echo "null"; fi
}
read_or_null_str() {
    if [ -n "$BATDIR" ] && [ -f "${BATDIR}$1" ]; then
        printf '"%s"' "$(cat "${BATDIR}$1")"
    else
        echo "null"
    fi
}

CAPACITY=$(read_or_null capacity)
HEALTH=$(read_or_null_str health)
STATUS=$(read_or_null_str status)
CYCLES=$(read_or_null cycle_count)
[ "$CYCLES" = "null" ] && CYCLES=$(read_or_null battery_cycle)
FULL=$(read_or_null charge_full)
DESIGN=$(read_or_null charge_full_design)
TEMP=$(read_or_null temp)

RETENTION="null"
if [ "$FULL" != "null" ] && [ "$DESIGN" != "null" ]; then
    RETENTION=$(awk "BEGIN{ if (${DESIGN}+0>0) printf \"%.1f\", (${FULL}/${DESIGN})*100; else print \"null\" }" 2>/dev/null)
    [ -z "$RETENTION" ] && RETENTION="null"
fi

# ── RAM — /proc/meminfo values are in kB.
MEM_TOTAL=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
MEM_AVAIL=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
MEM_FREE=$(awk '/^MemFree:/{print $2}' /proc/meminfo)

# ── CPU — load average (1/5/15 min) and core count.
LOAD1=$(awk '{print $1}' /proc/loadavg)
LOAD5=$(awk '{print $2}' /proc/loadavg)
LOAD15=$(awk '{print $3}' /proc/loadavg)
NPROC=$(grep -c '^processor' /proc/cpuinfo)

# ── Storage — /mnt/us is the main USB-visible document partition.
DF_LINE=$(df -h /mnt/us 2>/dev/null | tail -1)
STORAGE_SIZE=$(printf '"%s"' "$(echo "$DF_LINE" | awk '{print $2}')")
STORAGE_USED=$(printf '"%s"' "$(echo "$DF_LINE" | awk '{print $3}')")
STORAGE_AVAIL=$(printf '"%s"' "$(echo "$DF_LINE" | awk '{print $4}')")
STORAGE_PCT=$(printf '"%s"' "$(echo "$DF_LINE" | awk '{print $5}')")

# ── Uptime — /proc/uptime's first field is seconds since boot.
UPTIME_SEC=$(awk '{print int($1)}' /proc/uptime)
UPTIME_STR=$(awk -v s="$UPTIME_SEC" 'BEGIN{printf "%dh %dm", int(s/3600), int((s%3600)/60)}')

# ── SoC temperature — a separate thermal zone from the battery's own
# (thermal_zone0 on this device IS the battery; thermal_zone1 is the SoC).
SOC_TEMP="null"
for tz in /sys/class/thermal/thermal_zone*/; do
    if [ "$(cat "${tz}type" 2>/dev/null)" = "imx_thermal_zone" ]; then
        SOC_TEMP=$(awk -v t="$(cat "${tz}temp" 2>/dev/null)" 'BEGIN{printf "%.1f", t/1000}')
        break
    fi
done

# ── Device info — firmware pretty-version + kernel.
FW_VERSION=$(printf '"%s"' "$(cat /etc/prettyversion.txt 2>/dev/null | sed 's/ *(~~otaVersion~~)//' | tr -d '\n')")
KERNEL=$(printf '"%s"' "$(uname -r 2>/dev/null)")
ARCH=$(printf '"%s"' "$(uname -m 2>/dev/null)")

# ── Jailbreak & tools — /var/local/jailbreak.txt is written by the
# jailbreak installer itself regardless of which one is used (confirmed:
# it's read the same way by this device's own patch_system.sh), so this
# stays generic across jailbreak generations rather than checking for one
# specific jailbreak's marker.
JB_NAME="null"
if [ -f /var/local/jailbreak.txt ]; then
    JB_NAME=$(printf '"%s"' "$(head -n1 /var/local/jailbreak.txt 2>/dev/null | tr -d '\n')")
fi

KPM_BIN=""
for p in /var/local/kmc/bin/kpm /var/local/kmc/kindlehf/bin/kpm /var/local/kmc/kindlepw2/bin/kpm; do
    [ -x "$p" ] && KPM_BIN="$p" && break
done
KPM_VERSION="null"
if [ -n "$KPM_BIN" ]; then
    # kpm's own output is ANSI-colored (each line prefixed with an escape
    # code), so grep -m1 '^cli' never matches — strip escapes first.
    KPM_VERSION=$(printf '"%s"' "$("$KPM_BIN" version 2>&1 | \
        sed 's/\x1b\[[0-9;]*m//g' | grep -m1 'Package Manager' | \
        awk '{print $NF}')")
fi

KTERM_PRESENT="false"
[ -x /mnt/us/kterm/bin/kterm ] && KTERM_PRESENT="true"

KOREADER_PRESENT="false"
[ -d /mnt/us/documents/koreader ] || [ -d /mnt/us/koreader ] && KOREADER_PRESENT="true"

KINDLEFORGE_PRESENT="false"
[ -d /mnt/us/documents/KindleForge ] && KINDLEFORGE_PRESENT="true"

cat > "$OUT" <<EOF
{
  "time": "$(date '+%H:%M:%S')",
  "battery": {
    "capacity": ${CAPACITY},
    "health": ${HEALTH},
    "status": ${STATUS},
    "retention_pct": ${RETENTION},
    "cycles": ${CYCLES},
    "temp_c": ${TEMP}
  },
  "ram": {
    "total_kb": ${MEM_TOTAL:-null},
    "available_kb": ${MEM_AVAIL:-null},
    "free_kb": ${MEM_FREE:-null}
  },
  "cpu": {
    "load1": ${LOAD1:-null},
    "load5": ${LOAD5:-null},
    "load15": ${LOAD15:-null},
    "cores": ${NPROC:-null}
  },
  "storage": {
    "size": ${STORAGE_SIZE},
    "used": ${STORAGE_USED},
    "available": ${STORAGE_AVAIL},
    "used_pct": ${STORAGE_PCT}
  },
  "uptime": {
    "seconds": ${UPTIME_SEC:-null},
    "text": "${UPTIME_STR}"
  },
  "soc_temp_c": ${SOC_TEMP},
  "device": {
    "firmware": ${FW_VERSION},
    "kernel": ${KERNEL},
    "arch": ${ARCH}
  },
  "jailbreak": {
    "name": ${JB_NAME},
    "kpm_version": ${KPM_VERSION},
    "kterm": ${KTERM_PRESENT},
    "koreader": ${KOREADER_PRESENT},
    "kindleforge": ${KINDLEFORGE_PRESENT}
  }
}
EOF
