#!/data/data/com.termux/files/usr/bin/sh
export HOME=/data/data/com.termux/files/home
export TMPDIR=/data/data/com.termux/files/usr/tmp
export PATH=/data/data/com.termux/files/usr/bin:/system/bin
echo 'sh /sdcard/rish_test.sh' | sh ~/rish 2>&1
echo "wrapper_exit=$?"
