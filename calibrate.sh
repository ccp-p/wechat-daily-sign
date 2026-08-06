#!/system/bin/sh
# calibrate.sh - helper to measure UI coordinates via accessibility dump
# Usage: sh calibrate.sh [scene_id]
# Requires accessibility service enabled (for dump only, not for execution)

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"

UI_DUMP="/sdcard/wx_calibrate.xml"

dump_and_show() {
    local label="$1"
    echo ""
    echo "=== $label ==="
    rm -f "$UI_DUMP"
    uiautomator dump "$UI_DUMP" 2>/dev/null
    if [ ! -f "$UI_DUMP" ] || [ ! -s "$UI_DUMP" ]; then
        echo "DUMP FAILED - this is likely a webview page"
        echo "Take a screenshot and measure coordinates manually:"
        shot "calibrate_${label}"
        echo "Screenshot saved to $SHOT_DIR/calibrate_${label}_*.png"
        return 1
    fi
    echo "Dump OK. Found nodes:"
    cat "$UI_DUMP" | sed 's/<node/\n<node/g' | grep -o 'text="[^"]*"' | sed 's/text="//;s/"//' | grep -v '^$'
    echo ""
    echo "Nodes with bounds:"
    cat "$UI_DUMP" | sed 's/<node/\n<node/g' | grep 'text="[^"]' | while IFS= read -r line; do
        local txt bounds nums cx cy
        txt=$(echo "$line" | grep -o 'text="[^"]*"' | sed 's/text="//;s/"//')
        bounds=$(echo "$line" | grep -o 'bounds="\[[0-9,]*\]\[[0-9,]*\]"' | head -1)
        if [ -n "$bounds" ]; then
            nums=$(echo "$bounds" | sed 's/\]\[/,/g; s/[^0-9,]//g')
            local x1 y1 x2 y2
            x1=$(echo "$nums" | cut -d, -f1)
            y1=$(echo "$nums" | cut -d, -f2)
            x2=$(echo "$nums" | cut -d, -f3)
            y2=$(echo "$nums" | cut -d, -f4)
            cx=$(( (x1 + x2) / 2 ))
            cy=$(( (y1 + y2) / 2 ))
            echo "  text=[$txt] center=($cx,$cy) bounds=[$x1,$y1][$x2,$y2]"
        fi
    done
    shot "calibrate_${label}"
    echo "Screenshot saved."
    return 0
}

echo "=== WeChat Daily Sign-in Coordinate Calibration ==="
echo "Navigate your phone to the target page, then press Enter."
echo "Scene ID: ${1:-all}"

case "${1:-all}" in
    S00|s00) dump_and_show "S00_home" ;;
    S01|s01) dump_and_show "S01_search" ;;
    S02|s02) dump_and_show "S02_results" ;;
    S03|s03) dump_and_show "S03_wxpay" ;;
    S04|s04) dump_and_show "S04_pay_service" ;;
    S05|s05) dump_and_show "S05_bibisheng" ;;
    S06|s06) dump_and_show "S06_pay_discount" ;;
    S07|s07) dump_and_show "S07_exchange_gift" ;;
    S08|s08) dump_and_show "S08_voucher_100" ;;
    S09|s09) dump_and_show "S09_lottery" ;;
    S10|s10) dump_and_show "S10_confirm" ;;
    all)
        echo "Run with a scene ID: sh calibrate.sh S05"
        echo "Available: S00 S01 S02 S03 S04 S05 S06 S07 S08 S09 S10"
        ;;
esac

echo ""
echo "=== Done. Update coords.conf with measured coordinates. ==="
