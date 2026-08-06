#!/system/bin/sh
# S10_confirm.sh - Lottery animation -> result popup -> confirm -> END
# Context: webview page; lottery animation runs ~3-10s (per coords TO_ANIMATION).
# The result popup may render as a native overlay (dump works, "确认收下" visible)
# or inside the webview (dump empty). This is the FINAL scene:
# scene_pass "END" marks the daily flow complete.
SCENE_ID="S10"
. "$(dirname "$0")/../lib.sh"

log "=== S10: lottery confirm - wait for result popup ==="

# a. Poll for the result popup up to TO_ANIMATION seconds (1s per iteration).
#    dump_ui succeeds on a native popup overlay -> grep for "确认收下"/"收下".
#    dump_ui fails on a pure webview -> fall through to a blind tap at the end.
i=0
found=0
dump_ok=0
while [ "$i" -lt "$TO_ANIMATION" ]; do
    if dump_ui; then
        dump_ok=1
        if text_exists "确认收下" || text_exists "收下"; then
            found=1
            log "  result popup detected (confirm-receive text found)"
            break
        fi
    fi
    sleep 1
    i=$((i + 1))
done

if [ "$found" -eq 0 ]; then
    if [ "$dump_ok" -eq 1 ]; then
        log "  screen readable but popup text not found in ${TO_ANIMATION}s; blind-tapping confirm"
    else
        log "  webview (dump empty throughout); blind-tapping confirm at calibrated coord"
    fi
fi

# b. Tap "确认收下" (calibrated coordinate; best-effort for webview fallback).
tap_var "$C_LOTTERY_CONFIRM"

# c. Wait for popup dismissal / result to settle.
sleep 2

# d. Final screenshot as evidence.
shot "final_result"

# Verification: success if popup was detected, OR pure-webview blind-tap fallback
# (last scene -> accept the calibrated best-effort). Fail only when the screen was
# actually readable but never showed the confirm popup.
if [ "$found" -eq 1 ] || [ "$dump_ok" -eq 0 ]; then
    log "  confirm handled, daily flow complete"
    scene_pass "END"
else
    scene_fail "confirm popup not found"
fi
