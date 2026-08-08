#!/system/bin/sh
# Stop checkin - kills Termux and all child processes
am force-stop com.termux 2>/dev/null
echo "checkin stopped"
