#!/system/bin/sh
# S06: Enter "支付有优惠" from the pay service page (webview)
SCENE_ID="S06"
. "$(dirname "$0")/../lib.sh"
log "=== S06: enter 支付有优惠 ==="

# Identification: on pay service page (webview) after S05 returned.
# Webview pages return empty from dump_ui, so we navigate by coordinates
# and rely on screenshots for evidence rather than text detection.

# Action a: tap "支付有优惠" entry. If the coordinate is unset, the entry
# cannot be targeted (config/calibration issue) -> treat as not found.
if [ -z "$C_PAY_DISCOUNT" ]; then
    shot "s06_no_coord"
    scene_fail "pay discount entry not found"
fi

tap_var "$C_PAY_DISCOUNT"

# Action b: wait for webview page to settle
sleep "$TO_WEBVIEW"

# Action c: capture evidence of the resulting page
shot "pay_discount_page"

# Verification: screenshot evidence only (webview, dump_ui unreliable)
scene_pass "S07"
