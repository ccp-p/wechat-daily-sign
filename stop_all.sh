#!/system/bin/sh
# Stop all wx_sign/checkin processes
pkill -f wx_sign.sh 2>/dev/null
pkill -f checkin.sh 2>/dev/null
pkill -f rish 2>/dev/null
echo "stopped"
