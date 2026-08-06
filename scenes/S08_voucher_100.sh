#!/system/bin/sh
# S08: 100元额度兑换券 exchange (webview, FINANCIAL action)
# Arrives from S07 on the "平台提现福利" webview page.
# Attempts the 100 yuan voucher exchange once, captures evidence, backs out.
# IMPORTANT: Financial action - never retry after the exchange tap, since
# the exchange may have already succeeded and a retry would double-spend.
SCENE_ID="S08"
. "$(dirname "$0")/../lib.sh"

log "=== S08: 100 yuan voucher exchange (webview, financial) ==="

# --- Pre-flight: verify coordinates before any financial action ---
# Refuse to proceed with missing coordinates rather than risk tapping the
# wrong element. This scene_fail is safe because no exchange has happened.
if [ -z "$C_VOUCHER_100" ] || [ -z "$C_EXCHANGE_CLAIM" ]; then
    shot "s08_no_coords"
    scene_fail "coordinates not configured (C_VOUCHER_100/C_EXCHANGE_CLAIM)"
fi

# --- Identification ---
# On "平台提现福利" page (webview, after S07). dump_ui returns empty on
# webview, so identification relies on flow state + screenshot evidence.
shot "voucher_list"

# --- Action ---
# a. Click the left-side 100元额度兑换券 entry
tap_var "$C_VOUCHER_100"

# b. Wait for the detail page to load (webview transition)
sleep "$TO_WEBVIEW"

# c. Evidence: voucher detail page BEFORE exchange
shot "voucher_detail"

# d. Click the "兑换领取" button at the bottom of the detail page.
#    FINANCIAL COMMITMENT POINT: after this tap the exchange may have
#    succeeded, so we must NOT retry or scene_fail (which restarts flow).
tap_var "$C_EXCHANGE_CLAIM"

# e. Wait for the exchange result to appear
sleep "$TO_PAGE"

# f. Evidence: exchange result AFTER exchange
shot "exchange_result"

# g. Handle edge cases gracefully.
#    Webview may not expose text via uiautomator; screenshots are primary
#    evidence. We call dump_ui once: if it succeeds the cache is valid and
#    the text_exists greps are cheap; if it fails (typical webview) we skip
#    text checks rather than waste time on repeated failed dumps.
if dump_ui; then
    if text_exists "已兑换"; then
        log "  edge case: already exchanged today"
    elif text_exists "金币不足"; then
        log "  edge case: insufficient coins"
    elif text_exists "网络异常" || text_exists "网络错误" || text_exists "加载失败"; then
        log "  edge case: network error during exchange"
    else
        log "  exchange submitted (no edge case text detected)"
    fi
else
    log "  webview dump empty; exchange result captured in screenshot"
fi

# h. Return to the previous level / platform page
back

# i. Wait for the page transition to settle
sleep "$TO_PAGE"

# --- Verification ---
# Evidence: we returned to the platform page after the exchange attempt.
shot "after_exchange"

# --- Exit ---
# Financial action completed: we attempted the exchange exactly once,
# captured before/after evidence, and backed out safely. We pass forward
# to S09 regardless of edge cases, because scene_fail would restart the
# whole flow (S07 -> S08) and risk a duplicate exchange.
scene_pass "S09"
