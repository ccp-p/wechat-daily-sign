#!/system/bin/sh
SCENE_ID="S02"
. "$(dirname "$0")/../lib.sh"
log "=== S02: input search text '微信支付' ==="

# Action: type search text into the focused EditText
# Note: Chinese input via 'input text' requires ADBKeyboard IME on most devices
input text "微信支付"
sleep 2
shot "s02_search_input"

# Verify: search results appeared (result text or category label)
dump_ui
if grep -q "微信支付" "$UI_DUMP" 2>/dev/null || grep -q "公众号" "$UI_DUMP" 2>/dev/null; then
    shot "s02_search_results"
    scene_pass "S03"
fi

scene_fail "no search results"
