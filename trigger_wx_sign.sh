#!/system/bin/sh
# MacroDroid entry point - runs wx_sign directly via Shizuku, no Termux needed
RISH=/data/local/tmp/rish
LOG=/sdcard/wx-sign/cron.log
TS=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$TS] ===== WX_SIGN TRIGGERED =====" >> "$LOG"

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
    echo "[$TS] ===== WX_SIGN ABORTED =====" >> "$LOG"
    exit 1
fi

echo "[$TS] executing wx_sign.sh --reset" >> "$LOG"
echo 'sh /sdcard/wx_sign.sh --reset' | sh "$RISH" >> "$LOG" 2>&1
RC=$?

TS2=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$TS2] wx_sign.sh exited with code=$RC" >> "$LOG"
echo 'tail -10 /sdcard/wx-sign/flow.log' | sh "$RISH" >> "$LOG" 2>&1
echo "[$TS2] ===== WX_SIGN FINISHED =====" >> "$LOG"
