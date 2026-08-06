#!/system/bin/sh
# wx_sign.sh - WeChat daily sign-in (single file)
# Run: sh /sdcard/wx_sign.sh           # full run from current state
# Run: sh /sdcard/wx_sign.sh --reset    # reset state and run from S00
# Run: sh /sdcard/wx_sign.sh --scene S05 # run single scene (for testing)
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

# Swipe defaults
SWIPE_X=540
SWIPE_TOP=1800
SWIPE_BOT=400
SWIPE_MS=500

# S00-S02: native page coords (fallback when dump click fails)
C_SEARCH_BAR="540 152"
C_WXPAY_RESULT="540 400"

# S04: pay service tab (webview, bottom tab)
C_PAY_SERVICE_TAB="540 2280"

# S05: bibisheng voucher claim (webview)
C_TX_BIBISHENG="540 800"
C_TX_VOUCHER_CLAIM="810 1100"

# S06: pay discount entry (webview)
C_PAY_DISCOUNT="540 1200"

# S07: exchange gift -> coin voucher (webview)
C_EXCHANGE_GIFT="540 900"
C_COIN_VOUCHER="540 1100"

# S08: 100 yuan voucher exchange (webview)
C_VOUCHER_100="270 1000"
C_EXCHANGE_CLAIM="540 2200"

# S09: spend coins lottery (webview)
C_SPEND_COIN="810 1000"
C_LOTTERY_ACCEPT="540 1800"

# S10: lottery confirm popup (webview)
C_LOTTERY_CONFIRM="540 2000"

# Timeouts (seconds)
TO_LAUNCH=5
TO_PAGE=3
TO_WEBVIEW=5
TO_ANIMATION=15
TO_POPUP=10
TO_RETRY=3
MAX_RETRIES=4

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

shot() {
    screencap -p "$SHOT_DIR/$1_$(date +%s).png" 2>/dev/null
    log "  shot: $1"
}

# ===== UI dump (native pages; webview returns empty) =====
DUMP_VALID=0
invalidate_dump() { DUMP_VALID=0; }

dump_ui() {
    if [ "$DUMP_VALID" -eq 1 ] && [ -f "$UI_DUMP" ] && [ -s "$UI_DUMP" ]; then return 0; fi
    rm -f "$UI_DUMP"
    uiautomator dump "$UI_DUMP" 2>/dev/null
    if [ -f "$UI_DUMP" ] && [ -s "$UI_DUMP" ]; then DUMP_VALID=1; return 0; fi
    sleep 1
    uiautomator dump "$UI_DUMP" 2>/dev/null
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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $SCENE_ID: $1" >> "$RETRY_FILE"
    NEXT_STATE="S99"
    echo "S99" > "$STATE_FILE"
    return 1
}

read_state() { cat "$STATE_FILE" 2>/dev/null || echo "S00"; }
write_state() { echo "$1" > "$STATE_FILE"; }

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

# ===== Scene: S01 - Open search bar =====
scene_s01() {
    SCENE_ID="S01"
    log "=== S01: open search bar ==="

    if click_text "搜索"; then
        log "  clicked '搜索' via text"
    else
        log "  '搜索' text not found, using coordinate fallback"
        tap_var "$C_SEARCH_BAR"
    fi
    sleep 2
    shot "s01_search_opened"

    dump_ui
    if grep -q "EditText" "$UI_DUMP" 2>/dev/null; then
        shot "s01_search_input_ready"
        scene_pass "S02"; return 0
    fi

    scene_fail "search bar not found"; return 1
}

# ===== Scene: S02 - Input "微信支付" =====
scene_s02() {
    SCENE_ID="S02"
    log "=== S02: input search text '微信支付' ==="

    input text "微信支付"
    sleep 2
    shot "s02_search_input"

    dump_ui
    if grep -q "微信支付" "$UI_DUMP" 2>/dev/null || grep -q "公众号" "$UI_DUMP" 2>/dev/null; then
        shot "s02_search_results"
        scene_pass "S03"; return 0
    fi

    scene_fail "no search results"; return 1
}

# ===== Scene: S03 - Enter WeChat Pay official account =====
scene_s03() {
    SCENE_ID="S03"
    log "=== S03: enter WeChat Pay official account ==="

    if click_text "微信支付"; then
        log "  clicked '微信支付' result via text"
    else
        log "  '微信支付' result not found, using coordinate fallback"
        tap_var "$C_WXPAY_RESULT"
    fi
    sleep "$TO_PAGE"
    shot "s03_wxpay_entered"

    dump_ui
    if [ -f "$UI_DUMP" ] && [ -s "$UI_DUMP" ]; then
        if grep -q "EditText" "$UI_DUMP" 2>/dev/null; then
            shot "s03_still_on_search"
            scene_fail "wxpay not entered"; return 1
        fi
    fi

    shot "s03_wxpay_verified"
    scene_pass "S04"; return 0
}

# ===== Scene: S04 - Switch to "支付服务" tab (webview) =====
scene_s04() {
    SCENE_ID="S04"
    log "=== S04: pay service tab ==="

    sleep 2
    tap_var "$C_PAY_SERVICE_TAB"
    sleep "$TO_WEBVIEW"
    shot "pay_service_tab"

    FG=$(current_pkg)
    case "$FG" in
        *"$WECHAT_PKG"*)
            scene_pass "S05"; return 0 ;;
        *)
            log "  not in wechat: $FG"
            scene_fail "pay service tab timeout"; return 1 ;;
    esac
}

# ===== Scene: S05 - "提现比比省" voucher claim (webview) =====
scene_s05() {
    SCENE_ID="S05"
    log "=== S05: bibisheng voucher claim ==="

    tap_var "$C_TX_BIBISHENG"
    sleep "$TO_WEBVIEW"
    shot "bibisheng_page"

    tap_var "$C_TX_VOUCHER_CLAIM"
    sleep "$TO_PAGE"
    shot "claim_result"

    if dump_ui; then
        if text_exists "已领取" || text_exists "今日已领"; then
            log "  bibisheng already claimed today, continuing"
        fi
    fi

    back
    sleep "$TO_PAGE"
    shot "after_bibisheng"

    scene_pass "S06"; return 0
}

# ===== Scene: S06 - Enter "支付有优惠" (webview) =====
scene_s06() {
    SCENE_ID="S06"
    log "=== S06: enter 支付有优惠 ==="

    if [ -z "$C_PAY_DISCOUNT" ]; then
        shot "s06_no_coord"
        scene_fail "pay discount entry not found"; return 1
    fi

    tap_var "$C_PAY_DISCOUNT"
    sleep "$TO_WEBVIEW"
    shot "pay_discount_page"

    scene_pass "S07"; return 0
}

# ===== Scene: S07 - "兑换好礼" -> "金币提现券" (webview) =====
scene_s07() {
    SCENE_ID="S07"
    log "=== S07: 兑换好礼 -> 金币提现券 ==="

    if [ -z "$C_EXCHANGE_GIFT" ]; then
        shot "s07_no_exchange_coord"
        scene_fail "coin voucher not found"; return 1
    fi

    tap_var "$C_EXCHANGE_GIFT"
    sleep "$TO_WEBVIEW"
    shot "exchange_gift_page"

    if [ -z "$C_COIN_VOUCHER" ]; then
        shot "s07_no_voucher_coord"
        scene_fail "coin voucher not found"; return 1
    fi

    tap_var "$C_COIN_VOUCHER"
    sleep "$TO_WEBVIEW"
    shot "coin_voucher_page"

    scene_pass "S08"; return 0
}

# ===== Scene: S08 - 100元额度兑换券 exchange (webview, financial) =====
scene_s08() {
    SCENE_ID="S08"
    log "=== S08: 100 yuan voucher exchange (financial) ==="

    if [ -z "$C_VOUCHER_100" ] || [ -z "$C_EXCHANGE_CLAIM" ]; then
        shot "s08_no_coords"
        scene_fail "coordinates not configured"; return 1
    fi

    shot "voucher_list"

    tap_var "$C_VOUCHER_100"
    sleep "$TO_WEBVIEW"
    shot "voucher_detail"

    # FINANCIAL COMMITMENT POINT: never retry after this tap
    tap_var "$C_EXCHANGE_CLAIM"
    sleep "$TO_PAGE"
    shot "exchange_result"

    if dump_ui; then
        if text_exists "已兑换"; then
            log "  edge case: already exchanged today"
        elif text_exists "金币不足"; then
            log "  edge case: insufficient coins"
        elif text_exists "网络异常" || text_exists "网络错误" || text_exists "加载失败"; then
            log "  edge case: network error"
        else
            log "  exchange submitted"
        fi
    else
        log "  webview dump empty; result in screenshot"
    fi

    back
    sleep "$TO_PAGE"
    shot "after_exchange"

    # Always pass forward - never fail (avoids duplicate exchange on retry)
    scene_pass "S09"; return 0
}

# ===== Scene: S09 - "花金币" + "拼手气" accept (webview) =====
scene_s09() {
    SCENE_ID="S09"
    log "=== S09: lottery - spend coin & accept ==="

    tap_var "$C_SPEND_COIN"
    sleep "$TO_PAGE"
    shot "spend_coin_page"

    tap_var "$C_LOTTERY_ACCEPT"
    sleep 2
    shot "lottery_started"

    log "  lottery draw started, advancing to S10"
    scene_pass "S10"; return 0
}

# ===== Scene: S10 - Lottery animation -> confirm popup -> END =====
scene_s10() {
    SCENE_ID="S10"
    log "=== S10: lottery confirm - wait for result popup ==="

    i=0
    found=0
    dump_ok=0
    while [ "$i" -lt "$TO_ANIMATION" ]; do
        if dump_ui; then
            dump_ok=1
            if text_exists "确认收下" || text_exists "收下"; then
                found=1
                log "  result popup detected"
                break
            fi
        fi
        sleep 1
        i=$((i + 1))
    done

    if [ "$found" -eq 0 ]; then
        if [ "$dump_ok" -eq 1 ]; then
            log "  screen readable but no popup; blind-tapping confirm"
        else
            log "  webview dump empty; blind-tapping confirm"
        fi
    fi

    tap_var "$C_LOTTERY_CONFIRM"
    sleep 2
    shot "final_result"

    if [ "$found" -eq 1 ] || [ "$dump_ok" -eq 0 ]; then
        log "  confirm handled, daily flow complete"
        scene_pass "END"; return 0
    else
        scene_fail "confirm popup not found"; return 1
    fi
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
        if text_exists "微信支付"; then
            log "  identified: WeChat Pay"
            shot "reset_wxpay"
            scene_pass "S04"; return 0
        fi
        if text_exists "支付服务"; then
            log "  identified: pay service"
            shot "reset_pay_service"
            scene_pass "S05"; return 0
        fi
        if text_exists "微信"; then
            log "  identified: WeChat home"
            shot "reset_home"
            reset_retries
            scene_pass "S00"; return 0
        fi
        if text_exists "搜索"; then
            log "  identified: near home"
            shot "reset_near_home"
            reset_retries
            scene_pass "S01"; return 0
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
    echo "S01 search:      C_SEARCH_BAR=[$C_SEARCH_BAR]       [$( _cs $CAL_SEARCH_BAR )]"
    echo "S02 result:      C_WXPAY_RESULT=[$C_WXPAY_RESULT]     [$( _cs $CAL_WXPAY_RESULT )]"
    echo "S03 enter wxpay:  (native, dump-based, no coords)"
    echo "S04 pay service: C_PAY_SERVICE_TAB=[$C_PAY_SERVICE_TAB] [$( _cs $CAL_PAY_SERVICE_TAB )]"
    echo "S05 bibisheng:    C_TX_BIBISHENG=[$C_TX_BIBISHENG]     [$( _cs $CAL_TX_BIBISHENG )]"
    echo "                 C_TX_VOUCHER_CLAIM=[$C_TX_VOUCHER_CLAIM] [$( _cs $CAL_TX_VOUCHER_CLAIM )]"
    echo "S06 discount:    C_PAY_DISCOUNT=[$C_PAY_DISCOUNT]   [$( _cs $CAL_PAY_DISCOUNT )]"
    echo "S07 exchange:    C_EXCHANGE_GIFT=[$C_EXCHANGE_GIFT]   [$( _cs $CAL_EXCHANGE_GIFT )]"
    echo "                 C_COIN_VOUCHER=[$C_COIN_VOUCHER]  [$( _cs $CAL_COIN_VOUCHER )]"
    echo "S08 voucher100:  C_VOUCHER_100=[$C_VOUCHER_100]    [$( _cs $CAL_VOUCHER_100 )]"
    echo "                 C_EXCHANGE_CLAIM=[$C_EXCHANGE_CLAIM] [$( _cs $CAL_EXCHANGE_CLAIM )]"
    echo "S09 lottery:      C_SPEND_COIN=[$C_SPEND_COIN]     [$( _cs $CAL_SPEND_COIN )]"
    echo "                 C_LOTTERY_ACCEPT=[$C_LOTTERY_ACCEPT] [$( _cs $CAL_LOTTERY_ACCEPT )]"
    echo "S10 confirm:      C_LOTTERY_CONFIRM=[$C_LOTTERY_CONFIRM] [$( _cs $CAL_LOTTERY_CONFIRM )]"
    echo ""
    local todo=0 total=0 v val
    for v in CAL_SEARCH_BAR CAL_WXPAY_RESULT CAL_PAY_SERVICE_TAB CAL_TX_BIBISHENG \
             CAL_TX_VOUCHER_CLAIM CAL_PAY_DISCOUNT CAL_EXCHANGE_GIFT CAL_COIN_VOUCHER \
             CAL_VOUCHER_100 CAL_EXCHANGE_CLAIM CAL_SPEND_COIN CAL_LOTTERY_ACCEPT \
             CAL_LOTTERY_CONFIRM; do
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
        S01) echo "    C_SEARCH_BAR=$C_SEARCH_BAR [CAL=$CAL_SEARCH_BAR]" ;;
        S02) echo "    C_WXPAY_RESULT=$C_WXPAY_RESULT [CAL=$CAL_WXPAY_RESULT]" ;;
        S03) echo "    (none - dump-based)" ;;
        S04) echo "    C_PAY_SERVICE_TAB=$C_PAY_SERVICE_TAB [CAL=$CAL_PAY_SERVICE_TAB]" ;;
        S05) echo "    C_TX_BIBISHENG=$C_TX_BIBISHENG [CAL=$CAL_TX_BIBISHENG]"
             echo "    C_TX_VOUCHER_CLAIM=$C_TX_VOUCHER_CLAIM [CAL=$CAL_TX_VOUCHER_CLAIM]" ;;
        S06) echo "    C_PAY_DISCOUNT=$C_PAY_DISCOUNT [CAL=$CAL_PAY_DISCOUNT]" ;;
        S07) echo "    C_EXCHANGE_GIFT=$C_EXCHANGE_GIFT [CAL=$CAL_EXCHANGE_GIFT]"
             echo "    C_COIN_VOUCHER=$C_COIN_VOUCHER [CAL=$CAL_COIN_VOUCHER]" ;;
        S08) echo "    C_VOUCHER_100=$C_VOUCHER_100 [CAL=$CAL_VOUCHER_100]"
             echo "    C_EXCHANGE_CLAIM=$C_EXCHANGE_CLAIM [CAL=$CAL_EXCHANGE_CLAIM]" ;;
        S09) echo "    C_SPEND_COIN=$C_SPEND_COIN [CAL=$CAL_SPEND_COIN]"
             echo "    C_LOTTERY_ACCEPT=$C_LOTTERY_ACCEPT [CAL=$CAL_LOTTERY_ACCEPT]" ;;
        S10) echo "    C_LOTTERY_CONFIRM=$C_LOTTERY_CONFIRM [CAL=$CAL_LOTTERY_CONFIRM]" ;;
        S99) echo "    (none - uses dump for identification)" ;;
    esac
    echo ""
}

main() {
    log "====== wx_sign started ======"

    # Parse args
    local arg="${1:-}"
    case "$arg" in
        --check)
            check_coords
            exit 0
            ;;
        --reset)
            write_state "S00"
            reset_retries
            log "  state reset to S00"
            ;;
        --scene)
            # Run a single scene for testing: sh wx_sign.sh --scene S05
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
                S09) scene_s09 ;;
                S10) scene_s10 ;;
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
            S09) scene_s09 ;;
            S10) scene_s10 ;;
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

if [ "${1:-}" = "--check" ]; then check_coords; exit 0; fi; main "$@"
