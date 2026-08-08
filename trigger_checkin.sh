#!/system/bin/sh
# MacroDroid entry point - runs checkin directly via Shizuku, no Termux needed
RISH=/data/local/tmp/rish
LOG=/sdcard/checkin/checkin.log
TS=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$TS] ===== CHECKIN TRIGGERED =====" >> "$LOG"

# Probe Shizuku with retries (app_process cold start can be slow)
SHIZUKU_READY=0
for i in 1 2 3; do
    if echo 'echo SHIZUKU_OK' | timeout -s KILL 15 sh "$RISH" 2>/dev/null | grep -q SHIZUKU_OK; then
        SHIZUKU_READY=1
        break
    fi
    echo "[$TS] rish attempt $i failed, retrying..." >> "$LOG"
    sleep 2
done

if [ "$SHIZUKU_READY" -eq 0 ]; then
    echo "[$TS] ERROR: Shizuku not running. Open Shizuku app and start service, then retry." >> "$LOG"
    echo "[$TS] ===== CHECKIN ABORTED =====" >> "$LOG"
    exit 1
fi

echo "[$TS] executing checkin.sh" >> "$LOG"
echo 'sh /sdcard/checkin/checkin.sh' | sh "$RISH" >> "$LOG" 2>&1
RC=$?

TS2=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$TS2] checkin.sh exited with code=$RC" >> "$LOG"
echo "[$TS2] ===== CHECKIN FINISHED =====" >> "$LOG"
