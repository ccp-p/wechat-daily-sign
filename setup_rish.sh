#!/data/data/com.termux/files/usr/bin/sh
# Termux:Boot - copy rish to /data/local/tmp on every boot
export HOME=/data/data/com.termux/files/home
cp ~/rish /data/local/tmp/rish 2>/dev/null
cp ~/rish_shizuku.dex /data/local/tmp/rish_shizuku.dex 2>/dev/null
chmod 555 /data/local/tmp/rish 2>/dev/null
chmod 444 /data/local/tmp/rish_shizuku.dex 2>/dev/null
# Also copy start_shizuku.sh
cp ~/start-shizuku.sh /data/local/tmp/start_shizuku.sh 2>/dev/null
chmod 555 /data/local/tmp/start_shizuku.sh 2>/dev/null
