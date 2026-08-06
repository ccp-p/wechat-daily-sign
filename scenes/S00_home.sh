#!/system/bin/sh
SCENE_ID="S00"
. "$(dirname "$0")/../lib.sh"
log "=== S00: launch WeChat and verify home ==="

# Action: go home, cold-start WeChat
home
launch_wechat
sleep "$TO_LAUNCH"
shot "s00_home_launch"

# Verify: WeChat home page visible
dump_ui
if text_exists "微信"; then
    shot "s00_home_verified"
    scene_pass "S01"
fi

# Retry: a popup may cover the home page; back() dismisses it once
log "  '微信' not found, retrying with back()"
back
sleep 2
dump_ui
if text_exists "微信"; then
    shot "s00_home_verified_retry"
    scene_pass "S01"
fi

scene_fail "wechat not launched"
