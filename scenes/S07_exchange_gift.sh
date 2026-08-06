#!/system/bin/sh
# S07: "兑换好礼" -> "金币提现券" on the pay discount page (webview)
SCENE_ID="S07"
. "$(dirname "$0")/../lib.sh"
log "=== S07: 兑换好礼 -> 金币提现券 ==="

# Identification: on pay discount page (webview) after S06.
# Webview pages return empty from dump_ui, so we navigate by coordinates
# and rely on screenshots for evidence rather than text detection.

# Action a: tap "兑换好礼". Guard against an unset coordinate.
if [ -z "$C_EXCHANGE_GIFT" ]; then
    shot "s07_no_exchange_coord"
    scene_fail "coin voucher not found"
fi

tap_var "$C_EXCHANGE_GIFT"

# Action b: wait for webview page to settle
sleep "$TO_WEBVIEW"

# Action c: capture evidence of the exchange gift page
shot "exchange_gift_page"

# Action d: tap "金币提现券". Guard against an unset coordinate.
if [ -z "$C_COIN_VOUCHER" ]; then
    shot "s07_no_voucher_coord"
    scene_fail "coin voucher not found"
fi

tap_var "$C_COIN_VOUCHER"

# Action e: wait for webview page to settle
sleep "$TO_WEBVIEW"

# Action f: capture evidence of the resulting page
shot "coin_voucher_page"

# Verification: should be on "平台提现福利" page (screenshot evidence only)
scene_pass "S08"
