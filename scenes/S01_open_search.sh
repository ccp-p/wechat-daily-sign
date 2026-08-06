#!/system/bin/sh
SCENE_ID="S01"
. "$(dirname "$0")/../lib.sh"
log "=== S01: open search bar ==="

# Action: try text-based click, fall back to coordinate
if click_text "搜索"; then
    log "  clicked '搜索' via text"
else
    log "  '搜索' text not found, using coordinate fallback"
    tap_var "$C_SEARCH_BAR"
fi
sleep 2
shot "s01_search_opened"

# Verify: search input field (EditText) is present
dump_ui
if grep -q "EditText" "$UI_DUMP" 2>/dev/null; then
    shot "s01_search_input_ready"
    scene_pass "S02"
fi

scene_fail "search bar not found"
