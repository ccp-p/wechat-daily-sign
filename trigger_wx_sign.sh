#!/system/bin/sh
# MacroDroid entry point - runs wx_sign via Shizuku with binder recovery
RISH=/data/local/tmp/rish
LOG=/sdcard/wx-sign/cron.log
TS=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$TS] ===== WX_SIGN TRIGGERED =====" >> "$LOG"

# Wake screen first - Doze freezes binder, screen on helps unfreeze
input keyevent 224 2>/dev/null
sleep 1

# Probe Shizuku with retries
SHIZUKU_READY=0
for i in 1 2 3 4 5; do
    if echo 'echo SHIZUKU_OK' | timeout -s KILL 15 sh "$RISH" 2>/dev/null | grep -q SHIZUKU_OK; then
        SHIZUKU_READY=1
        break
    fi
    echo "[$TS] rish attempt $i failed, retrying..." >> "$LOG"
    # Doze can freeze binder; wake screen + launch Shizuku app to unfreeze
    input keyevent 224 2>/dev/null
    monkey -p moe.shizuku.privileged.api -c android.intent.category.LAUNCHER 1 2>/dev/null
    sleep 5
done

if [ "$SHIZUKU_READY" -eq 0 ]; then
    echo "[$TS] ERROR: Shizuku not running after 5 retries." >> "$LOG"
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
