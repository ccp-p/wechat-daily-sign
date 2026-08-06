#!/system/bin/sh
# lib.sh - primitive operations for WeChat daily sign-in
# All scene scripts source this: . "$(dirname "$0")/../lib.sh"
# Designed for Android shell (mksh/dash), no bash-isms

# ===== Paths =====
BASE_DIR="/sdcard/wx-sign"
CONF_FILE="$BASE_DIR/coords.conf"
LOG_FILE="$BASE_DIR/flow.log"
SHOT_DIR="$BASE_DIR/screenshots"
STATE_FILE="$BASE_DIR/state.txt"
RETRY_FILE="$BASE_DIR/retry.log"
UI_DUMP="/sdcard/wx_ui_dump.xml"
WECHAT_PKG="com.tencent.mm"

# Load coordinates (may not exist yet during calibration)
[ -f "$CONF_FILE" ] && . "$CONF_FILE"

# ===== Logging =====
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" >&2; }

# ===== Screen operations =====
# tap <x> <y> - click and invalidate dump cache
tap() { input tap "$1" "$2"; log "  tap ($1,$2)"; invalidate_dump; }

# tap_var "540 152" - click using a coords.conf variable (space-separated)
tap_var() { input tap $1; log "  tap_var $1"; invalidate_dump; }

# Swipe helpers
swipe_up() {
    local x=${SWIPE_X:-540} top=${SWIPE_TOP:-1800} bot=${SWIPE_BOT:-400} ms=${SWIPE_MS:-500}
    input swipe "$x" "$top" "$x" "$bot" "$ms"; log "  swipe up"; invalidate_dump
}
swipe_down() {
    local x=${SWIPE_X:-540} top=${SWIPE_TOP:-400} bot=${SWIPE_BOT:-1800} ms=${SWIPE_MS:-500}
    input swipe "$x" "$top" "$x" "$bot" "$ms"; log "  swipe down"; invalidate_dump
}

back() { input keyevent 4; invalidate_dump; log "  back"; }
home() { input keyevent 3; invalidate_dump; log "  home"; }

shot() {
    mkdir -p "$SHOT_DIR"
    screencap -p "$SHOT_DIR/$1_$(date +%s).png" 2>/dev/null
    log "  shot: $1"
}

# ===== UI dump (native pages; webview pages return empty) =====
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

# text_exists "keyword" - grep dump XML for keyword
text_exists() { dump_ui || return 1; grep -q "$1" "$UI_DUMP" 2>/dev/null; }

# wait_for_text "keyword" timeout_seconds
wait_for_text() {
    local text="$1" timeout="${2:-10}"
    local dl=$(( $(date +%s) + timeout ))
    while [ $(date +%s) -lt $dl ]; do
        if text_exists "$text"; then return 0; fi
        invalidate_dump; sleep 1
    done
    return 1
}

# wait_for_any "text1" "text2" timeout
wait_for_any() {
    local t1="$1" t2="$2" timeout="${3:-10}"
    local dl=$(( $(date +%s) + timeout ))
    while [ $(date +%s) -lt $dl ]; do
        if text_exists "$t1" || text_exists "$t2"; then return 0; fi
        invalidate_dump; sleep 1
    done
    return 1
}

# click_text "keyword" - parse bounds from dump XML, click center
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

# click_text_wait "keyword" timeout
click_text_wait() {
    if wait_for_text "$1" "$2"; then click_text "$1"; return $?; fi
    log "  timeout: $1"; return 1
}

# ===== State management =====
read_state() { cat "$STATE_FILE" 2>/dev/null || echo "S00"; }
write_state() { echo "$1" > "$STATE_FILE"; }

# ===== Scene exit helpers =====
SCENE_ID="?"

scene_pass() {
    log "  [PASS] $SCENE_ID -> $1"
    write_state "$1"
    exit 0
}

scene_fail() {
    log "  [FAIL] $SCENE_ID -> S99 ($1)"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $SCENE_ID: $1" >> "$RETRY_FILE"
    write_state "S99"
    exit 1
}

# ===== App control =====
launch_wechat() {
    am force-stop "$WECHAT_PKG" 2>/dev/null
    sleep 1
    am start -n com.tencent.mm/.ui.LauncherUI 2>/dev/null
    log "  launch wechat"
}

current_pkg() {
    dumpsys window | grep 'mCurrentFocus' | head -1
}

# ===== 3x3 scan-tap: try a grid around expected coords =====
# Usage: scan_tap <cx> <cy> [step]
# Taps 9 points in a grid, 1s apart. Caller checks effectiveness between calls.
scan_tap() {
    local cx=$1 cy=$2 step=${3:-50}
    local x y
    for dy in -1 0 1; do
        for dx in -1 0 1; do
            x=$((cx + dx * step))
            y=$((cy + dy * step))
            tap "$x" "$y"; sleep 1
        done
    done
}

# ===== Dump all visible texts (for debugging) =====
print_screen() {
    dump_ui || return 1
    cat "$UI_DUMP" | sed 's/<node/\n<node/g' | grep -o 'text="[^"]*"' | sed 's/text="//;s/"//' | grep -v '^$' | head -30 >> "$LOG_FILE"
}

# ===== Retry count (for flow.sh safety) =====
retry_count() {
    cat "$RETRY_FILE" 2>/dev/null | wc -l
}

reset_retries() {
    : > "$RETRY_FILE" 2>/dev/null
}
