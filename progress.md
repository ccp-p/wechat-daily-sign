# WeChat Daily Sign-in - Progress Tracker

## Overall Status: SINGLE FILE COMPLETE

### Deliverable

**wx_sign.sh** - one file, self-contained. Push to phone and run.

### Scene Status

| Scene | Description | Status | Strategy |
|-------|-------------|--------|----------|
| S00 | WeChat home | done | native+dump |
| S01 | Open search bar | done | native+dump |
| S02 | Input "微信支付" | done | native+dump |
| S03 | Enter WeChat Pay | done | native+dump |
| S04 | Pay service tab | done | webview+coords |
| S05 | Bibisheng claim | done | webview+coords |
| S06 | Pay discount | done | webview+coords |
| S07 | Exchange gift + coin voucher | done | webview+coords |
| S08 | 100 yuan voucher exchange | done | webview+coords |
| S09 | Spend coins lottery | done | webview+coords |
| S10 | Lottery confirm popup | done | webview+coords |
| S99 | Fallback reset | done | hybrid |

### Usage

```sh
sh /sdcard/wx_sign.sh            # full run
sh /sdcard/wx_sign.sh --reset     # reset and run
sh /sdcard/wx_sign.sh --scene S05 # test single scene
```

### Calibration Tracking

```sh
sh /sdcard/wx_sign.sh --check     # show coordinate calibration checklist
```

Each coordinate has a CAL_xxx status flag (0=TODO, 1=verified).
After measuring on device, set CAL_xxx=1 to mark it verified.
--check prints a summary: "X/13 verified, Y TODO".

### Coordinate Status

| Scene | Coords | Status |
|-------|--------|--------|
| S00 | none (dump-based) | n/a |
| S01 | C_SEARCH_BAR | TODO |
| S02 | C_WXPAY_RESULT | TODO |
| S03 | none (dump-based) | n/a |
| S04 | C_PAY_SERVICE_TAB | TODO |
| S05 | C_TX_BIBISHENG, C_TX_VOUCHER_CLAIM | TODO |
| S06 | C_PAY_DISCOUNT | TODO |
| S07 | C_EXCHANGE_GIFT, C_COIN_VOUCHER | TODO |
| S08 | C_VOUCHER_100, C_EXCHANGE_CLAIM | TODO |
| S09 | C_SPEND_COIN, C_LOTTERY_ACCEPT | TODO |
| S10 | C_LOTTERY_CONFIRM | TODO |

Calibration workflow per scene:
1. Navigate phone to scene's starting page
2. Run: sh /sdcard/wx_sign.sh --scene SXX (preview shows coords used)
3. Check screenshot to verify tap landed correctly
4. If off, measure correct coords, update value + set CAL_xxx=1
5. Re-run --scene to confirm
6. Repeat for next scene

### Syntax Check

wx_sign.sh passes `sh -n` (POSIX shell).

### Scene -> Agent Mapping (development)

| Agent | Scenes |
|-------|--------|
| Linnaeus | S00, S01, S02, S03 |
| Raman | S04, S05 |
| Jason | S06, S07 |
| Herschel | S08 |
| Feynman | S09, S10 |
| Pascal | S99 |

### Key Design Decisions

- S00-S03: native UI, uiautomator dump works, click_text for dynamic bounds
- S04-S10: webview, dump returns empty, fixed coordinates + screenshots
- S08: financial action, never retries exchange (passes forward regardless)
- S10: blind-tap fallback for webview, only fails if dump worked but no popup
- S99: resets retries only on fully-recovered states (S00/S01), not mid-flow
- coords inline at top of wx_sign.sh: single source, calibrate once per device
- scene_pass/scene_fail use return (not exit) so main loop runs all scenes

### Next Steps

1. Push wx_sign.sh to phone
2. Calibrate coordinates (navigate to each page, measure, update top of file)
3. Test each scene: `sh /sdcard/wx_sign.sh --scene S04`
4. Full run: `sh /sdcard/wx_sign.sh --reset`
5. Set up cron

### Change Log

- 2026-08-06: project scaffold created, infrastructure files done
- 2026-08-06: 6 sub-agents spawned for parallel scene implementation
- 2026-08-06: all 12 scenes implemented, S08 syntax bug fixed
- 2026-08-06: merged all into single wx_sign.sh (coords inline, scenes as functions)
- 2026-08-06: added --scene flag for single-scene testing, --reset for state reset
- 2026-08-06: added --check calibration checklist with CAL_xxx status tracking
- 2026-08-06: --scene mode now previews coords used before execution
- 2026-08-13: enhanced lottery/exchange scenes (S05-S08) with edge case handling
  - S05: pre-flight coord guard, text-based coin voucher click fallback
  - S06: pre-flight coord guard, pre-exchange screenshot, pre-check for
    already-exchanged/insufficient-coins, scan_exchange_result helper
    (covers 兑换成功/已兑换/金币不足/兑换失败/网络异常)
  - S07: pre-flight coord guard, extended cooldown patterns (明天再来/今日已抽),
    insufficient-coins pre-check before draw, fixed button order (拼手气 first)
  - S08: fixed dump cache bug (invalidate_dump per loop iteration),
    scan_lottery_result helper (谢谢参与/再抽一次/金币不足/恭喜/完成),
    dismiss-button fallback chain, secondary popup dismiss, always pass to END
  - Added scan_exchange_result() and scan_lottery_result() helper functions
