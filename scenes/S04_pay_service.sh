#!/system/bin/sh
# S04 - Switch to "支付服务" tab on the WeChat Pay official account page.
# This is a WEBVIEW page: uiautomator dump returns empty, so all interaction
# is coordinate-based and verification relies on screenshots.
SCENE_ID="S04"
. "$(dirname "$0")/../lib.sh"

log "=== S04: pay service tab ==="

# a. Let the webview settle after entering from S03 (native -> webview handoff).
sleep 2

# b. Tap the bottom "支付服务" tab.
tap_var "$C_PAY_SERVICE_TAB"

# c. Webview tab switches are slow; wait for the new panel to render.
sleep "$TO_WEBVIEW"

# d. Capture evidence of the pay service page.
shot "pay_service_tab"

# Verification: webview cannot be dump-verified. Treat the tab switch as
# success as long as we are still inside WeChat. Only fail on an extreme
# timeout where WeChat itself is no longer the foreground package (crash /
# unexpected exit), which counts as an unrecoverable condition.
FG=$(current_pkg)
case "$FG" in
    *"$WECHAT_PKG"*)
        scene_pass "S05"
        ;;
    *)
        log "  not in wechat: $FG"
        scene_fail "pay service tab timeout"
        ;;
esac
