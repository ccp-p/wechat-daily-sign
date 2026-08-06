#!/system/bin/sh
# flow.sh - orchestrator: read state, run one scene, advance
# Designed to be called by cron - runs ONE scene per invocation
# State persists in state.txt, so interruptions resume automatically

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"

log "====== flow started, state=$(read_state) ======"

# Safety: stop if too many consecutive failures
RC=$(retry_count)
if [ "$RC" -ge "$MAX_RETRIES" ]; then
    log "FATAL: $RC consecutive failures, stopping for safety"
    log "====== flow aborted (retry limit) ======"
    exit 2
fi

STATE=$(read_state)
SCENE_FILE="$DIR/scenes/${STATE}_*.sh"

case "$STATE" in
    S00) sh "$DIR/scenes/S00_home.sh" ;;
    S01) sh "$DIR/scenes/S01_open_search.sh" ;;
    S02) sh "$DIR/scenes/S02_input_wxpay.sh" ;;
    S03) sh "$DIR/scenes/S03_enter_wxpay.sh" ;;
    S04) sh "$DIR/scenes/S04_pay_service.sh" ;;
    S05) sh "$DIR/scenes/S05_bibisheng.sh" ;;
    S06) sh "$DIR/scenes/S06_pay_discount.sh" ;;
    S07) sh "$DIR/scenes/S07_exchange_gift.sh" ;;
    S08) sh "$DIR/scenes/S08_voucher_100.sh" ;;
    S09) sh "$DIR/scenes/S09_lottery.sh" ;;
    S10) sh "$DIR/scenes/S10_confirm.sh" ;;
    S99) sh "$DIR/scenes/S99_reset.sh" ;;
    END)
        log "====== already completed today ======"
        exit 0
        ;;
    *)
        log "unknown state: $STATE, resetting to S00"
        write_state "S00"
        sh "$DIR/scenes/S00_home.sh"
        ;;
esac

EXIT_CODE=$?
log "====== flow ended, exit=$EXIT_CODE, state=$(read_state) ======"
exit $EXIT_CODE
