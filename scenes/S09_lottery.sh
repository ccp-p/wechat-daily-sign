#!/system/bin/sh
# S09_lottery.sh - Spend coins lottery: tap "花金币" then "拼手气" accept
# Context: webview platform page reached after S08 voucher exchange.
# Per rule 6, dump_ui returns empty on webview pages -> rely on calibrated
# coordinates and screenshot evidence rather than text detection.
SCENE_ID="S09"
. "$(dirname "$0")/../lib.sh"

log "=== S09: lottery - spend coin & accept ==="

# a. Tap "花金币" (spend coin) on the right side of the platform page.
log "  tap 花金币 (C_SPEND_COIN)"
tap_var "$C_SPEND_COIN"

# b. Wait for the lottery/spend-coin page to load.
sleep "$TO_PAGE"

# c. Screenshot evidence of the spend-coin page.
shot "spend_coin_page"

# d. Tap "拼手气" accept/receive button to start the lottery draw.
log "  tap 拼手气 accept (C_LOTTERY_ACCEPT)"
tap_var "$C_LOTTERY_ACCEPT"

# e. Let the lottery animation begin.
sleep 2

# f. Screenshot evidence that the draw/animation has started.
shot "lottery_started"

# Verification: lottery animation started (captured via screenshot above).
# Webview page -> no dump-based text check; coordinates + shots are the signal.
# On success advance to S10 (animation -> confirm popup).
log "  lottery draw started, advancing to S10"
scene_pass "S10"
