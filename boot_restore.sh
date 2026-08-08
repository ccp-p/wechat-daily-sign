#!/data/data/com.termux/files/usr/bin/sh
# Termux:Boot - restore rish + start Shizuku on every boot
export HOME=/data/data/com.termux/files/home
export TMPDIR=/data/data/com.termux/files/usr/tmp
export PATH=/data/data/com.termux/files/usr/bin:/system/bin:$PATH
LOG=~/checkin_cron.log
TS=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$TS] ===== BOOT RESTORE =====" >> "$LOG"

# Copy rish to /data/local/tmp
cp ~/rish /data/local/tmp/rish 2>/dev/null
cp ~/rish_shizuku.dex /data/local/tmp/rish_shizuku.dex 2>/dev/null
chmod 555 /data/local/tmp/rish 2>/dev/null
chmod 444 /data/local/tmp/rish_shizuku.dex 2>/dev/null
cp ~/start-shizuku.sh /data/local/tmp/start_shizuku.sh 2>/dev/null
chmod 555 /data/local/tmp/start_shizuku.sh 2>/dev/null
echo "[$TS] rish copied to /data/local/tmp" >> "$LOG"

# Start Shizuku (delay 10s to let adbd initialize)
echo "[$TS] scheduling Shizuku start in 10s..." >> "$LOG"
(sleep 10 && sh ~/start-shizuku.sh >> "$LOG" 2>&1) &

echo "[$TS] ===== BOOT RESTORE DONE =====" >> "$LOG"
