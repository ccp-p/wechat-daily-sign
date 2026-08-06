#!/system/bin/sh
SCENE_ID="S99"
. "$(dirname "$0")/../lib.sh"
log "=== S99: fallback reset and recovery ==="

# Safety guard: stop the flow if we have failed too many times.
# Without this, a permanently broken state would loop S99 forever.
retries=$(retry_count)
if [ "$retries" -ge "$MAX_RETRIES" ]; then
    log "  max retries exceeded ($retries/$MAX_RETRIES), giving up"
    scene_fail "max retries"
fi

# Action: back out of any popup/dialog that may be blocking the screen
log "  backing out of popups"
back; sleep 1
back; sleep 1
back; sleep 1
shot "reset_after_back"

# Identification: dump UI and match against known page markers.
# Each match exits via scene_pass, so falling past them means no match.
if dump_ui; then
    if text_exists "微信"; then
        log "  identified: WeChat home"
        shot "reset_home"
        reset_retries
        scene_pass "S00"
    fi
    if text_exists "搜索"; then
        log "  identified: near home (search page)"
        shot "reset_near_home"
        reset_retries
        scene_pass "S01"
    fi
    if text_exists "微信支付"; then
        log "  identified: WeChat Pay"
        shot "reset_wxpay"
        scene_pass "S04"
    fi
    if text_exists "支付服务"; then
        log "  identified: pay service"
        shot "reset_pay_service"
        scene_pass "S05"
    fi
    # Dump succeeded but no known marker matched - log what we see
    log "  page not recognized, logging visible text"
    print_screen
fi

# Fallback: could not identify any known page - restart WeChat from scratch.
# Goal is recovery, not perfection: restart from S00 when in doubt.
log "  could not identify page, restarting WeChat"
home
sleep 1
launch_wechat
sleep "$TO_LAUNCH"
shot "reset_unknown"
scene_pass "S00"
