#!/system/bin/sh
SCENE_ID="S03"
. "$(dirname "$0")/../lib.sh"
log "=== S03: enter WeChat Pay official account ==="

# Action: try text-based click on first result, fall back to coordinate
if click_text "微信支付"; then
    log "  clicked '微信支付' result via text"
else
    log "  '微信支付' result not found, using coordinate fallback"
    tap_var "$C_WXPAY_RESULT"
fi
sleep "$TO_PAGE"
shot "s03_wxpay_entered"

# Verify: we left the search page. After entering, the page becomes a
# webview so dump may be empty. If dump is available, confirm the search
# input (EditText) is gone -- its presence means we are still searching.
dump_ui
if [ -f "$UI_DUMP" ] && [ -s "$UI_DUMP" ]; then
    if grep -q "EditText" "$UI_DUMP" 2>/dev/null; then
        shot "s03_still_on_search"
        scene_fail "wxpay not entered"
    fi
fi

# Empty dump (webview entered) or search page gone -> success
shot "s03_wxpay_verified"
scene_pass "S04"
