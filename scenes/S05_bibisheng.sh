#!/system/bin/sh
# S05 - "提现比比省" voucher claim on the pay service page.
# WEBVIEW page: uiautomator dump returns empty, so interaction is
# coordinate-based. Already-claimed ("已领取"/"今日已领") is handled gracefully.
SCENE_ID="S05"
. "$(dirname "$0")/../lib.sh"

log "=== S05: bibisheng voucher claim ==="

# a. Tap the "提现比比省" entry on the pay service page.
tap_var "$C_TX_BIBISHENG"

# b. Wait for the bibisheng page (webview) to render.
sleep "$TO_WEBVIEW"

# c. Capture evidence of the bibisheng page.
shot "bibisheng_page"

# d. Tap the claim button beneath the voucher.
tap_var "$C_TX_VOUCHER_CLAIM"

# e. Wait for the claim result page/popup.
sleep "$TO_PAGE"

# f. Capture evidence of the claim result.
shot "claim_result"

# g. Handle "already claimed" gracefully. Webview dump is unreliable, but if
#    a dump happens to succeed and shows already-claimed text, log and carry
#    on instead of treating it as a failure.
if dump_ui; then
    if text_exists "已领取" || text_exists "今日已领"; then
        log "  bibisheng already claimed today, continuing"
    fi
fi

# h. Return to the pay service page.
back

# i. Wait for the page transition to settle.
sleep "$TO_PAGE"

# Verification: back on the pay service page.
shot "after_bibisheng"

scene_pass "S06"
