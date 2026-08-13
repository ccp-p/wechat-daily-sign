#!/system/bin/sh
# wx_sign.sh - WeChat daily sign-in (single file)
# Run: sh /sdcard/wx_sign.sh           # full run from current state
# Run: sh /sdcard/wx_sign.sh --reset    # reset state and run from S00
# Run: sh /sdcard/wx_sign.sh --scene S02 # run single scene (for testing)
# Run: sh /sdcard/wx_sign.sh --check     # show coordinate calibration checklist
#
# State persists in /sdcard/wx-sign/state.txt for crash recovery.
# cron can call this repeatedly; if killed mid-flow it resumes.
# Coordinates are templates - calibrate each scene before production use.

# ===== Paths =====
BASE_DIR="/sdcard/wx-sign"
LOG_FILE="$BASE_DIR/flow.log"
SHOT_DIR="$BASE_DIR/screenshots"
STATE_FILE="$BASE_DIR/state.txt"
RETRY_FILE="$BASE_DIR/retry.log"
UI_DUMP="/sdcard/wx_ui_dump.xml"
WECHAT_PKG="com.tencent.mm"

mkdir -p "$BASE_DIR" "$SHOT_DIR"

# ===== Coordinates (calibrate on your device) =====
# Device: OPPO PJZ110 1080x2376 - adjust for other resolutions
# CAL_xxx=0 means TODO (not calibrated), =1 means verified on device
# Run: sh /sdcard/wx_sign.sh --check  to see calibration checklist

# Swipe defaults
SWIPE_X=540
SWIPE_TOP=1800
SWIPE_BOT=400
SWIPE_MS=500

# S01: WeChat Pay entry on chat list (native, dump-based via click_text)
# No coords needed - finds "微信支付" text wherever it is in the list

# S02: pay service tab (webview, bottom tab)
C_PAY_SERVICE_TAB="540 2280"
CAL_PAY_SERVICE_TAB=0

# S03: 提现笔笔省 voucher claim (webview)
C_TX_BIBISHENG="540 800"
CAL_TX_BIBISHENG=0
C_TX_VOUCHER_CLAIM="810 1100"
CAL_TX_VOUCHER_CLAIM=0

# S04: pay discount entry (webview)
C_PAY_DISCOUNT="540 1200"
CAL_PAY_DISCOUNT=0

# S05: exchange gift -> coin voucher (webview)
C_EXCHANGE_GIFT="540 900"
CAL_EXCHANGE_GIFT=0
C_COIN_VOUCHER="277 489"
CAL_COIN_VOUCHER=0

# S06: 100 yuan voucher exchange (webview)
C_VOUCHER_100="280 855"
CAL_VOUCHER_100=0
C_EXCHANGE_CLAIM="582 2052"
CAL_EXCHANGE_CLAIM=0

# S07: spend coins lottery (webview)
C_SPEND_COIN="799 994"
CAL_SPEND_COIN=0
C_LOTTERY_ACCEPT="540 1435"
CAL_LOTTERY_ACCEPT=0

# S08: lottery confirm popup (webview)
C_LOTTERY_CONFIRM_DLG="750 1285"
CAL_LOTTERY_CONFIRM_DLG=0
C_LOTTERY_CONFIRM="540 1800"
CAL_LOTTERY_CONFIRM=0

# Timeouts (seconds)
TO_LAUNCH=5
TO_PAGE=3
TO_WEBVIEW=5
TO_ANIMATION=15
TO_POPUP=10
TO_RETRY=3
MAX_RETRIES=4
DEBUG=0
# ===== Logging =====
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" >&2; }

# ===== Screen primitives =====
tap() { input tap "$1" "$2"; log "  tap ($1,$2)"; invalidate_dump; }

tap_var() { input tap $1; log "  tap_var $1"; invalidate_dump; }

swipe_up() {
    input swipe "$SWIPE_X" "$SWIPE_TOP" "$SWIPE_X" "$SWIPE_BOT" "$SWIPE_MS"
    log "  swipe up"; invalidate_dump
}
swipe_down() {
    input swipe "$SWIPE_X" "$SWIPE_BOT" "$SWIPE_X" "$SWIPE_TOP" "$SWIPE_MS"
    log "  swipe down"; invalidate_dump
}

back() { input keyevent 4; invalidate_dump; log "  back"; }
home() { input keyevent 3; invalidate_dump; log "  home"; }

wake_screen() {
    input keyevent 224 2>/dev/null
    sleep 1
    log "  screen woken"
}

shot() {
    return 0
}

# Always-fire screenshot (for failures)
shot_fail() {
    return 0
}

# ===== UI dump (native pages; webview returns empty) =====
DUMP_VALID=0
invalidate_dump() { DUMP_VALID=0; }

dump_ui() {
    if [ "$DUMP_VALID" -eq 1 ] && [ -f "$UI_DUMP" ] && [ -s "$UI_DUMP" ]; then return 0; fi
    rm -f "$UI_DUMP"
    uiautomator dump --compressed "$UI_DUMP" 2>/dev/null
    if [ -f "$UI_DUMP" ] && [ -s "$UI_DUMP" ]; then DUMP_VALID=1; return 0; fi
    sleep 1
    uiautomator dump --compressed "$UI_DUMP" 2>/dev/null
    if [ -f "$UI_DUMP" ] && [ -s "$UI_DUMP" ]; then DUMP_VALID=1; return 0; fi
    return 1
}

text_exists() { dump_ui || return 1; grep -q "$1" "$UI_DUMP" 2>/dev/null; }

wait_for_text() {
    local text="$1" timeout="${2:-10}"
    local dl=$(( $(date +%s) + timeout ))
    while [ $(date +%s) -lt $dl ]; do
        if text_exists "$text"; then return 0; fi
        invalidate_dump; sleep 1
    done
    return 1
}

wait_for_any() {
    local t1="$1" t2="$2" timeout="${3:-10}"
    local dl=$(( $(date +%s) + timeout ))
    while [ $(date +%s) -lt $dl ]; do
        if text_exists "$t1" || text_exists "$t2"; then return 0; fi
        invalidate_dump; sleep 1
    done
    return 1
}

click_text() {
    local text="$1"
    dump_ui || return 1
    local line
    line=$(cat "$UI_DUMP" | sed 's/<node/\n<node/g' | grep "text=\"$text\"" | head -1)
    [ -z "$line" ] && line=$(cat "$UI_DUMP" | sed 's/<node/\n<node/g' | grep "$text" | head -1)
    [ -z "$line" ] && return 1
    local bounds
    bounds=$(echo "$line" | grep -o 'bounds="\[[0-9,]*\]\[[0-9,]*\]"' | head -1)
    [ -z "$bounds" ] && return 1
    local nums
    nums=$(echo "$bounds" | sed 's/\]\[/,/g; s/[^0-9,]//g')
    local x1 y1 x2 y2 cx cy
    x1=$(echo "$nums" | cut -d, -f1)
    y1=$(echo "$nums" | cut -d, -f2)
    x2=$(echo "$nums" | cut -d, -f3)
    y2=$(echo "$nums" | cut -d, -f4)
    cx=$(( (x1 + x2) / 2 ))
    cy=$(( (y1 + y2) / 2 ))
    tap "$cx" "$cy"
    return 0
}

click_text_wait() {
    if wait_for_text "$1" "$2"; then click_text "$1"; return $?; fi
    log "  timeout: $1"; return 1
}

print_screen() {
    dump_ui || return 1
    cat "$UI_DUMP" | sed 's/<node/\n<node/g' | grep -o 'text="[^"]*"' | sed 's/text="//;s/"//' | grep -v '^$' | head -30 >> "$LOG_FILE"
}

launch_wechat() {
    am force-stop "$WECHAT_PKG" 2>/dev/null
    sleep 1
    am start -n com.tencent.mm/.ui.LauncherUI 2>/dev/null
    log "  launch wechat"
}

current_pkg() {
    dumpsys window | grep 'mCurrentFocus' | head -1
}

scan_tap() {
    local cx=$1 cy=$2 step=${3:-50} x y
    for dy in -1 0 1; do
        for dx in -1 0 1; do
            x=$((cx + dx * step))
            y=$((cy + dy * step))
            tap "$x" "$y"; sleep 1
        done
    done
}

retry_count() { cat "$RETRY_FILE" 2>/dev/null | wc -l; }
reset_retries() { : > "$RETRY_FILE" 2>/dev/null; }

# ===== State management =====
# scene_pass/scene_fail set NEXT_STATE + return (not exit)
# so main loop can continue to the next scene in one invocation
NEXT_STATE=""
SCENE_ID="?"

scene_pass() {
    log "  [PASS] $SCENE_ID -> $1"
    NEXT_STATE="$1"
    echo "$1" > "$STATE_FILE"
    return 0
}

scene_fail() {
    log "  [FAIL] $SCENE_ID -> S99 ($1)"
    shot_fail "$SCENE_ID"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $SCENE_ID: $1" >> "$RETRY_FILE"
    NEXT_STATE="S99"
    echo "S99" > "$STATE_FILE"
    return 1
}

read_state() { cat "$STATE_FILE" 2>/dev/null || echo "S00"; }
write_state() { echo "$1" > "$STATE_FILE"; }

# ===== Result scanning helpers =====
# Scan exchange outcome from current dump; logs result category.
# Returns 0 if dump was readable, 1 if webview dump empty.
scan_exchange_result() {
    if ! dump_ui; then
        log "  webview dump empty; result in screenshot only"
        return 1
    fi
    if text_exists "兑换成功"; then
        log "  exchange result: SUCCESS"
    elif text_exists "已兑换" || text_exists "今日已兑"; then
        log "  exchange result: ALREADY_EXCHANGED (safe)"
    elif text_exists "金币不足" || text_exists "金币不够"; then
        log "  exchange result: INSUFFICIENT_COINS"
    elif text_exists "兑换失败"; then
        log "  exchange result: FAILED"
    elif text_exists "网络异常" || text_exists "网络错误" || text_exists "加载失败"; then
        log "  exchange result: NETWORK_ERROR"
    else
        log "  exchange result: SUBMITTED (no error detected)"
    fi
    return 0
}

# Scan lottery outcome from current dump; logs result, returns 0 if known.
scan_lottery_result() {
    if ! dump_ui; then
        return 1
    fi
    if text_exists "确认收下" || text_exists "收下"; then
        log "  lottery result: WON_PRIZE (confirm popup)"
        return 0
    fi
    if text_exists "立即收下"; then
        log "  lottery result: WON_PRIZE (claim button)"
        return 0
    fi
    if text_exists "谢谢参与"; then
        log "  lottery result: NO_PRIZE (thanks for participating)"
        return 0
    fi
    if text_exists "再抽一次"; then
        log "  lottery result: DRAW_AGAIN offered (ignoring, daily limit)"
        return 0
    fi
    if text_exists "金币不足" || text_exists "金币不够"; then
        log "  lottery result: INSUFFICIENT_COINS"
        return 0
    fi
    if text_exists "恭喜" || text_exists "获得"; then
        log "  lottery result: WON (prize text)"
        return 0
    fi
    if text_exists "完成" || text_exists "知道了" || text_exists "确定"; then
        log "  lottery result: DISMISS button found"
        return 0
    fi
    return 1
}

# ===== Scene: S00 - Launch WeChat, verify home =====
scene_s00() {
    SCENE_ID="S00"
    log "=== S00: launch WeChat and verify home ==="
    home
    launch_wechat
    sleep "$TO_LAUNCH"
    shot "s00_home_launch"

    dump_ui
    if text_exists "微信"; then
        shot "s00_home_verified"
        scene_pass "S01"; return 0
    fi

    log "  '微信' not found, retrying with back()"
    back
    sleep 2
    dump_ui
    if text_exists "微信"; then
        shot "s00_home_verified_retry"
        scene_pass "S01"; return 0
    fi

    scene_fail "wechat not launched"; return 1
}

# ===== Scene: S01 - Click WeChat Pay in chat list =====
scene_s01() {
    SCENE_ID="S01"
    log "=== S01: click WeChat Pay in chat list ==="

    dump_ui
    if click_text "微信支付"; then
        log "  clicked '微信支付' in chat list"
    else
        log "  '微信支付' not found, scrolling to top and retrying"
        swipe_down
        sleep 1
        dump_ui
        if click_text "微信支付"; then
            log "  clicked '微信支付' after scroll to top"
        else
            shot "s01_wxpay_not_found"
            scene_fail "WeChat Pay not found in chat list"; return 1
        fi
    fi
    sleep "$TO_PAGE"
    shot "s01_wxpay_entered"

    # Verify we left the chat list (bottom tab bar should be gone)
    invalidate_dump
    dump_ui
    if text_exists "通讯录" && text_exists "发现"; then
        log "  still on chat list, retrying click"
        click_text "微信支付"
        sleep "$TO_PAGE"
        invalidate_dump
        dump_ui
        if text_exists "通讯录" && text_exists "发现"; then
            shot "s01_still_on_chatlist"
            scene_fail "did not enter WeChat Pay"; return 1
        fi
    fi

    shot "s01_wxpay_verified"
    scene_pass "S02"; return 0
}

# ===== Scene: S02 - Switch to "支付服务" tab (webview) =====
scene_s02() {
    SCENE_ID="S02"
    log "=== S02: pay service tab ==="

    sleep 2
    tap_var "$C_PAY_SERVICE_TAB"
    sleep "$TO_WEBVIEW"
    shot "pay_service_tab"

    FG=$(current_pkg)
    case "$FG" in
        *"$WECHAT_PKG"*)
            scene_pass "S03"; return 0 ;;
        *)
            log "  not in wechat: $FG"
            scene_fail "pay service tab timeout"; return 1 ;;
    esac
}

# ===== Scene: S03 - "提现笔笔省" voucher claim (webview) =====
scene_s03() {
    SCENE_ID="S03"
    log "=== S03: 提现笔笔省 voucher claim ==="

    if click_text_wait "提现笔笔省" "$TO_WEBVIEW"; then
        log "  clicked '提现笔笔省' via text"
    else
        log "  '提现笔笔省' not found, using coordinate fallback"
        tap_var "$C_TX_BIBISHENG"
    fi
    sleep "$TO_WEBVIEW"

    # Check if already claimed before clicking
    invalidate_dump
    if text_exists "已领取" || text_exists "今日已领"; then
        log "  bibisheng already claimed today, skipping"
        back
        sleep "$TO_PAGE"
        scene_pass "S04"; return 0
    fi

    # Not claimed yet, find and click the claim button
    if click_text_wait "领取" "$TO_PAGE"; then
        log "  clicked '领取' on bibisheng page"
    else
        log "  '领取' not found, trying coordinate fallback"
        tap_var "$C_TX_VOUCHER_CLAIM"
    fi
    sleep "$TO_PAGE"

    # Check result
    invalidate_dump
    if dump_ui; then
        if text_exists "已领取" || text_exists "今日已领"; then
            log "  bibisheng claimed successfully"
        fi
    fi

    back
    sleep "$TO_PAGE"

    scene_pass "S04"; return 0
}

# ===== Scene: S04 - Enter "支付有优惠" (webview) =====
scene_s04() {
    SCENE_ID="S04"
    log "=== S04: enter 支付有优惠 ==="

    if click_text_wait "支付有优惠" "$TO_WEBVIEW"; then
        log "  clicked '支付有优惠' via text"
    else
        log "  '支付有优惠' not found, using coordinate fallback"
        tap_var "$C_PAY_DISCOUNT"
    fi
    sleep "$TO_WEBVIEW"
    shot "pay_discount_page"

    scene_pass "S05"; return 0
}

# ===== Scene: S05 - "兑换好礼" -> "金币提现券" (webview) =====
scene_s05() {
    SCENE_ID="S05"
    log "=== S05: 兑换好礼 -> 金币提现券 ==="

    # Pre-flight: refuse to navigate with missing coordinates
    if [ -z "$C_EXCHANGE_GIFT" ] || [ -z "$C_COIN_VOUCHER" ]; then
        shot "s05_no_coords"
        scene_fail "coordinates not configured (C_EXCHANGE_GIFT/C_COIN_VOUCHER)"; return 1
    fi

    # Action a: enter "兑换好礼" section
    if click_text_wait "兑换好礼" "$TO_WEBVIEW"; then
        log "  clicked '兑换好礼' via text"
    else
        log "  '兑换好礼' not found, using coordinate fallback"
        tap_var "$C_EXCHANGE_GIFT"
    fi
    sleep "$TO_WEBVIEW"
    shot "exchange_gift_page"

    # Action b: enter coin voucher page (image-based; try text first, then coordinate)
    if click_text "金币提现券" 2>/dev/null || click_text "提现券" 2>/dev/null; then
        log "  clicked coin voucher via text"
    else
        log "  coin voucher text not found, using coordinate"
        tap_var "$C_COIN_VOUCHER"
    fi
    sleep "$TO_WEBVIEW"
    shot "coin_voucher_page"

    scene_pass "S06"; return 0
}

# ===== Scene: S06 - 100元额度兑换券 exchange (webview, financial) =====
scene_s06() {
    SCENE_ID="S06"
    log "=== S06: 100 yuan voucher exchange (financial) ==="

    # Pre-flight: refuse financial action with missing coordinates
    if [ -z "$C_VOUCHER_100" ] || [ -z "$C_EXCHANGE_CLAIM" ]; then
        shot "s06_no_coords"
        scene_fail "coordinates not configured (C_VOUCHER_100/C_EXCHANGE_CLAIM)"; return 1
    fi

    shot "voucher_list"

    # Action a: enter 100元额度 voucher detail page
    if click_text_wait "100元额度" "$TO_WEBVIEW"; then
        log "  clicked '100元额度' voucher via text"
    else
        log "  '100元额度' not found, using coordinate fallback"
        tap_var "$C_VOUCHER_100"
    fi
    sleep "$TO_WEBVIEW"
    shot "voucher_detail"

    # Pre-check: already exchanged or insufficient coins -> skip safely
    invalidate_dump
    if dump_ui; then
        if text_exists "已兑换" || text_exists "今日已兑"; then
            log "  already exchanged today, skipping"
            back; sleep "$TO_PAGE"
            scene_pass "S07"; return 0
        fi
        if text_exists "金币不足" || text_exists "金币不够"; then
            log "  insufficient coins detected, skipping exchange"
            back; sleep "$TO_PAGE"
            scene_pass "S07"; return 0
        fi
    fi

    # FINANCIAL COMMITMENT POINT: after this tap the exchange may have
    # succeeded, so we must NOT retry or scene_fail (would double-spend).
    if click_text_wait "1金币兑换" "$TO_PAGE"; then
        log "  clicked '1金币兑换' via text"
    else
        log "  '1金币兑换' not found, using coordinate"
        tap_var "$C_EXCHANGE_CLAIM"
    fi
    sleep "$TO_PAGE"
    shot "exchange_tapped"

    # Handle second confirmation dialog (native overlay, dump should work)
    invalidate_dump
    if click_text_wait "确认兑换" "$TO_PAGE"; then
        log "  clicked '确认兑换' on confirm dialog"
    else
        log "  no confirm dialog, proceeding"
    fi
    sleep "$TO_PAGE"

    # Scan result (best-effort; webview may not expose text)
    invalidate_dump
    scan_exchange_result
    shot "exchange_result"

    # Back out: 兑换结果 -> 兑换详情 -> 平台提现福利 (two levels)
    back; sleep "$TO_PAGE"
    back; sleep "$TO_PAGE"

    # Always pass forward - never fail (avoids duplicate exchange on retry)
    scene_pass "S07"; return 0
}

# ===== Scene: S07 - "花金币" + "拼手气" accept (webview) =====
scene_s07() {
    SCENE_ID="S07"
    log "=== S07: 抽提现券 -> 1金币抽提现券 -> 确认使用1金币 ==="

    # Pre-flight: refuse with missing coordinates
    if [ -z "$C_SPEND_COIN" ] || [ -z "$C_LOTTERY_ACCEPT" ]; then
        scene_fail "coordinates not configured (C_SPEND_COIN/C_LOTTERY_ACCEPT)"; return 1
    fi

    # Cooldown check: already claimed -> 7-day cooldown
    invalidate_dump
    if dump_ui; then
        if text_exists "7天后可再参与" || text_exists "已领取" || text_exists "已收下"; then
            log "  lottery in cooldown (already claimed), skipping"
            scene_pass "END"; return 0
        fi
    fi

    # Step 1: find and click "抽提现券" on the platform page
    if click_text_wait "抽提现券" "$TO_WEBVIEW"; then
        log "  clicked '抽提现券' via text"
    else
        log "  '抽提现券' not found, using coordinate fallback"
        tap_var "$C_SPEND_COIN"
    fi
    sleep "$TO_WEBVIEW"

    # Step 2: find and click "1金币抽提现券" on the lottery page
    invalidate_dump
    if click_text_wait "1金币抽提现券" "$TO_WEBVIEW"; then
        log "  clicked '1金币抽提现券' via text"
    else
        log "  '1金币抽提现券' not found, using coordinate fallback"
        tap_var "$C_LOTTERY_ACCEPT"
    fi
    sleep 2

    # Step 3: handle confirmation dialog "确认使用1金币抽提现券吗?"
    # FINANCIAL COMMITMENT POINT: after confirming, the coin is spent.
    invalidate_dump
    if click_text_wait "使用1金币" "$TO_PAGE"; then
        log "  clicked '使用1金币' on confirm dialog"
    else
        log "  '使用1金币' not found, using coordinate fallback"
        tap_var "$C_LOTTERY_CONFIRM_DLG"
    fi
    sleep 2

    log "  lottery draw started, advancing to S08"
    scene_pass "S08"; return 0
}

# ===== Scene: S08 - Lottery animation -> confirm popup -> END =====
scene_s08() {
    SCENE_ID="S08"
    log "=== S08: lottery confirm - wait for result popup ==="

    # Poll for result popup up to TO_ANIMATION seconds.
    # invalidate_dump each iteration to get fresh dumps (fixes stale cache).
    i=0
    found=0
    dump_ok=0
    while [ "$i" -lt "$TO_ANIMATION" ]; do
        invalidate_dump
        if dump_ui; then
            dump_ok=1
            if scan_lottery_result; then
                found=1
                break
            fi
        fi
        sleep 1
        i=$((i + 1))
    done

    if [ "$found" -eq 0 ]; then
        if [ "$dump_ok" -eq 1 ]; then
            log "  screen readable but no result detected; blind-tapping"
        else
            log "  webview dump empty; blind-tapping"
        fi
    fi

    # Dismiss result: try claim buttons, then dismiss buttons, then coord
    invalidate_dump
    if click_text "立即收下" 2>/dev/null || click_text "确认收下" 2>/dev/null || click_text "收下" 2>/dev/null; then
        log "  clicked claim-receive via text"
    elif click_text "完成" 2>/dev/null || click_text "知道了" 2>/dev/null || click_text "确定" 2>/dev/null; then
        log "  clicked dismiss via text (no-prize or done)"
    else
        log "  result button not found via text, using coordinate"
        tap_var "$C_LOTTERY_CONFIRM"
    fi
    sleep 2

    # Best-effort: dismiss any secondary popup/toast
    sleep 1
    invalidate_dump
    if dump_ui; then
        click_text "完成" 2>/dev/null || click_text "知道了" 2>/dev/null || click_text "确定" 2>/dev/null
    fi

    # Last scene: always pass to END. Failing here gains nothing -
    # S99 recovery would restart and re-trigger the lottery (double-draw risk).
    log "  lottery flow complete, daily sign-in done"
    scene_pass "END"; return 0
}

# ===== Scene: S99 - Fallback reset and recovery =====
scene_s99() {
    SCENE_ID="S99"
    log "=== S99: fallback reset and recovery ==="

    retries=$(retry_count)
    if [ "$retries" -ge "$MAX_RETRIES" ]; then
        log "  max retries exceeded ($retries/$MAX_RETRIES), giving up"
        scene_fail "max retries"; return 1
    fi

    log "  backing out of popups"
    back; sleep 1
    back; sleep 1
    back; sleep 1
    shot "reset_after_back"

    if dump_ui; then
        # Chat list: bottom tabs visible
        if text_exists "通讯录" && text_exists "发现"; then
            log "  identified: WeChat chat list"
            shot "reset_chatlist"
            reset_retries
            scene_pass "S01"; return 0
        fi
        if text_exists "支付服务"; then
            log "  identified: pay service"
            shot "reset_pay_service"
            scene_pass "S03"; return 0
        fi
        if text_exists "微信"; then
            log "  identified: WeChat home or wxpay page"
            shot "reset_home"
            reset_retries
            scene_pass "S00"; return 0
        fi
        log "  page not recognized, logging visible text"
        print_screen
    fi

    log "  could not identify page, restarting WeChat"
    home
    sleep 1
    launch_wechat
    sleep "$TO_LAUNCH"
    shot "reset_unknown"
    scene_pass "S00"; return 0
}

# ===== Main dispatcher =====

# Print calibration checklist: which coords are verified, which are TODO
check_coords() {
    echo "=== Coordinate Calibration Checklist ==="
    echo ""
    _cs() { [ "$1" -eq 1 ] && echo "OK " || echo "TODO"; }
    echo "S00 home:        (native, dump-based, no coords)"
    echo "S01 wxpay entry: (native, click_text, no coords)"
    echo "S02 pay service: C_PAY_SERVICE_TAB=[$C_PAY_SERVICE_TAB] [$( _cs $CAL_PAY_SERVICE_TAB )]"
    echo "S03 bibisheng:    C_TX_BIBISHENG=[$C_TX_BIBISHENG]     [$( _cs $CAL_TX_BIBISHENG )]"
    echo "                 C_TX_VOUCHER_CLAIM=[$C_TX_VOUCHER_CLAIM] [$( _cs $CAL_TX_VOUCHER_CLAIM )]"
    echo "S04 discount:    C_PAY_DISCOUNT=[$C_PAY_DISCOUNT]   [$( _cs $CAL_PAY_DISCOUNT )]"
    echo "S05 exchange:    C_EXCHANGE_GIFT=[$C_EXCHANGE_GIFT]   [$( _cs $CAL_EXCHANGE_GIFT )]"
    echo "                 C_COIN_VOUCHER=[$C_COIN_VOUCHER]  [$( _cs $CAL_COIN_VOUCHER )]"
    echo "S06 voucher100:  C_VOUCHER_100=[$C_VOUCHER_100]    [$( _cs $CAL_VOUCHER_100 )]"
    echo "                 C_EXCHANGE_CLAIM=[$C_EXCHANGE_CLAIM] [$( _cs $CAL_EXCHANGE_CLAIM )]"
    echo "S07 lottery:      C_SPEND_COIN=[$C_SPEND_COIN]     [$( _cs $CAL_SPEND_COIN )]"
    echo "                 C_LOTTERY_ACCEPT=[$C_LOTTERY_ACCEPT] [$( _cs $CAL_LOTTERY_ACCEPT )]"
    echo "S07 confirm dlg:  C_LOTTERY_CONFIRM_DLG=[$C_LOTTERY_CONFIRM_DLG] [$( _cs $CAL_LOTTERY_CONFIRM_DLG )]"
    echo "S08 confirm:      C_LOTTERY_CONFIRM=[$C_LOTTERY_CONFIRM] [$( _cs $CAL_LOTTERY_CONFIRM )]"
    echo ""
    local todo=0 total=0 v val
    for v in CAL_PAY_SERVICE_TAB CAL_TX_BIBISHENG \
             CAL_TX_VOUCHER_CLAIM CAL_PAY_DISCOUNT CAL_EXCHANGE_GIFT CAL_COIN_VOUCHER \
             CAL_VOUCHER_100 CAL_EXCHANGE_CLAIM CAL_SPEND_COIN CAL_LOTTERY_ACCEPT \
             CAL_LOTTERY_CONFIRM_DLG CAL_LOTTERY_CONFIRM; do
        eval "val=\${$v}"
        total=$((total + 1))
        [ "$val" -ne 1 ] && todo=$((todo + 1))
    done
    echo "Summary: $((total - todo))/$total verified, $todo TODO"
    [ "$todo" -gt 0 ] && echo "Calibrate: measure on device, set CAL_xxx=1 at top of file"
}

# Preview which coords a scene uses (printed before --scene runs)
preview_coords() {
    local s="$1"
    echo "  Coords used by $s:"
    case "$s" in
        S00) echo "    (none - dump-based)" ;;
        S01) echo "    (none - click_text based)" ;;
        S02) echo "    C_PAY_SERVICE_TAB=$C_PAY_SERVICE_TAB [CAL=$CAL_PAY_SERVICE_TAB]" ;;
        S03) echo "    C_TX_BIBISHENG=$C_TX_BIBISHENG [CAL=$CAL_TX_BIBISHENG]"
             echo "    C_TX_VOUCHER_CLAIM=$C_TX_VOUCHER_CLAIM [CAL=$CAL_TX_VOUCHER_CLAIM]" ;;
        S04) echo "    C_PAY_DISCOUNT=$C_PAY_DISCOUNT [CAL=$CAL_PAY_DISCOUNT]" ;;
        S05) echo "    C_EXCHANGE_GIFT=$C_EXCHANGE_GIFT [CAL=$CAL_EXCHANGE_GIFT]"
             echo "    C_COIN_VOUCHER=$C_COIN_VOUCHER [CAL=$CAL_COIN_VOUCHER]" ;;
        S06) echo "    C_VOUCHER_100=$C_VOUCHER_100 [CAL=$CAL_VOUCHER_100]"
             echo "    C_EXCHANGE_CLAIM=$C_EXCHANGE_CLAIM [CAL=$CAL_EXCHANGE_CLAIM]" ;;
        S07) echo "    C_SPEND_COIN=$C_SPEND_COIN [CAL=$CAL_SPEND_COIN]"
            echo "    C_LOTTERY_ACCEPT=$C_LOTTERY_ACCEPT [CAL=$CAL_LOTTERY_ACCEPT]"
            echo "    C_LOTTERY_CONFIRM_DLG=$C_LOTTERY_CONFIRM_DLG [CAL=$CAL_LOTTERY_CONFIRM_DLG]" ;;
        S08) echo "    C_LOTTERY_CONFIRM=$C_LOTTERY_CONFIRM [CAL=$CAL_LOTTERY_CONFIRM]" ;;
        S99) echo "    (none - uses dump for identification)" ;;
    esac
    echo ""
}

main() {
    log "====== wx_sign started ======"

    wake_screen

    # Parse args
    local arg="${1:-}"
    case "$arg" in
        --check)
            check_coords
            exit 0
            ;;
        --debug)
            DEBUG=1
            log "  debug mode: screenshots enabled"
            ;;
        --reset)
            write_state "S00"
            reset_retries
            log "  state reset to S00"
            ;;
        --scene)
            # Run a single scene for testing: sh wx_sign.sh --scene S03
            DEBUG=1
            local target="${2:-S00}"
            echo ""
            preview_coords "$target"
            log "  single-scene mode: $target"
            case "$target" in
                S00) scene_s00 ;;
                S01) scene_s01 ;;
                S02) scene_s02 ;;
                S03) scene_s03 ;;
                S04) scene_s04 ;;
                S05) scene_s05 ;;
                S06) scene_s06 ;;
                S07) scene_s07 ;;
                S08) scene_s08 ;;
                S99) scene_s99 ;;
                *) log "  unknown scene: $target"; exit 1 ;;
            esac
            log "====== single scene done, state=$(read_state) ======"
            exit $?
            ;;
    esac

    # Full run: loop scenes until END or failure
    while true; do
        STATE=$(read_state)
        log "  current state: $STATE"

        case "$STATE" in
            S00) scene_s00 ;;
            S01) scene_s01 ;;
            S02) scene_s02 ;;
            S03) scene_s03 ;;
            S04) scene_s04 ;;
            S05) scene_s05 ;;
            S06) scene_s06 ;;
            S07) scene_s07 ;;
            S08) scene_s08 ;;
            S99) scene_s99 ;;
            END)
                log "====== already completed ======"
                exit 0
                ;;
            *)
                log "  unknown state: $STATE, resetting to S00"
                write_state "S00"
                continue
                ;;
        esac

        RC=$?
        NEW_STATE=$(read_state)
        log "  scene returned rc=$RC, state=$NEW_STATE"

        # Safety: too many consecutive failures
        RCOUNT=$(retry_count)
        if [ "$RCOUNT" -ge "$MAX_RETRIES" ]; then
            log "FATAL: $RCOUNT consecutive failures, stopping"
            log "====== flow aborted (retry limit) ======"
            exit 2
        fi

        # Stop on END
        if [ "$NEW_STATE" = "END" ]; then
            log "====== flow complete ======"
            exit 0
        fi

        # If scene failed (went to S99), let S99 try to recover,
        # then it will either pass to a known scene or restart.
        # The loop continues naturally.
        sleep 1
    done
}

main "$@"
