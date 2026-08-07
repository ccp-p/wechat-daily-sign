#!/data/data/com.termux/files/usr/bin/sh
# Run wx_sign.sh via rish (Shizuku shell)
# WeChat daily sign-in: 提现笔笔省 + 金币兑换 + 抽奖

export HOME=/data/data/com.termux/files/home
export TMPDIR=/data/data/com.termux/files/usr/tmp
LOG=~/wx_sign_cron.log
TS=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$TS] ===== WX_SIGN CRON TRIGGERED =====" >> "$LOG"

# Check if rish exists
if [ ! -f ~/rish ]; then
    echo "[$TS] ERROR: ~/rish not found!" >> "$LOG"
    exit 1
fi

# Check if Shizuku is alive
echo "[$TS] probing Shizuku..." >> "$LOG"
if echo 'echo SHIZUKU_OK' | timeout -s KILL 8 sh ~/rish 2>/dev/null | grep -q SHIZUKU_OK; then
    echo "[$TS] Shizuku is running" >> "$LOG"
else
    echo "[$TS] Shizuku not responding, auto-starting..." >> "$LOG"
    sh ~/start-shizuku.sh >> "$LOG" 2>&1
    sleep 2
    if echo 'echo SHIZUKU_OK' | timeout -s KILL 8 sh ~/rish 2>/dev/null | grep -q SHIZUKU_OK; then
        echo "[$TS] Shizuku recovered successfully" >> "$LOG"
    else
        echo "[$TS] ERROR: Shizuku recovery failed!" >> "$LOG"
        echo "[$TS] ===== WX_SIGN CRON ABORTED (no Shizuku) =====" >> "$LOG"
        exit 1
    fi
fi

# Check if wx_sign.sh exists
if [ ! -f /sdcard/wx_sign.sh ]; then
    echo "[$TS] ERROR: /sdcard/wx_sign.sh not found!" >> "$LOG"
    echo "[$TS] ===== WX_SIGN CRON ABORTED =====" >> "$LOG"
    exit 1
fi

echo "[$TS] executing wx_sign.sh --reset via rish" >> "$LOG"
echo 'sh /sdcard/wx_sign.sh --reset' | sh ~/rish
RC=$?

TS2=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$TS2] wx_sign.sh exited with code=$RC" >> "$LOG"

# Show last 10 lines of flow log
echo "[$TS2] --- flow.log tail ---" >> "$LOG"
echo 'tail -10 /sdcard/wx-sign/flow.log' | sh ~/rish >> "$LOG" 2>&1
echo "[$TS2] ===== WX_SIGN CRON FINISHED =====" >> "$LOG"