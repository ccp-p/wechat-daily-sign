# WeChat Daily Sign-in

Single-file Android shell script for WeChat daily check-in automation.
No root, no accessibility service needed for execution.

## Deploy

Push ONE file to your phone:
```
adb push wechat-daily-sign/wx_sign.sh /sdcard/wx_sign.sh
```

## Usage

```sh
# Full run (from start to finish, or resumes from last state)
sh /sdcard/wx_sign.sh

# Reset state and run from beginning
sh /sdcard/wx_sign.sh --reset

# Test a single scene (phone must already be on that page)
sh /sdcard/wx_sign.sh --scene S05
```

## Flow

```
S00 WeChat home
  -> S01 open search
  -> S02 input "微信支付"
  -> S03 enter WeChat Pay official account
  -> S04 switch to "支付服务" tab
  -> S05 "提现比比省" -> claim voucher -> back
  -> S06 "支付有优惠"
  -> S07 "兑换好礼" -> "金币提现券"
  -> S08 100元额度兑换券 -> exchange -> back
  -> S09 "花金币" -> "拼手气" accept
  -> S10 lottery animation -> "确认收下"
  -> END
```

Any scene failure -> S99 fallback -> retry from S00 (max 4 times).

## Coordinate Strategy

| Page type | Identification | Action |
|-----------|---------------|--------|
| Native UI (S00-S03) | uiautomator dump | click_text (parse bounds) |
| Webview (S04-S10) | fixed coordinates + screenshots | tap_var |

All coordinates are at the top of wx_sign.sh (lines 18-60).
Calibrate once per device, then the script runs without accessibility.

## State Persistence

State saves to `/sdcard/wx-sign/state.txt`. If the script is killed
mid-flow (e.g. cron timeout), the next run resumes from where it left off.

## Files

| File | Purpose | Deploy to phone? |
|------|---------|-----------------|
| wx_sign.sh | The script | YES (only this one) |
| calibrate.sh | Coordinate calibration helper | optional |
| progress.md | Development tracker | no |
| README.md | This doc | no |
| scenes/*.sh | Original per-scene files (reference) | no |
| lib.sh, flow.sh, coords.conf | Original split files (reference) | no |

## Cron Setup

```sh
# Daily at 9:00 AM
0 9 * * * sh /sdcard/wx_sign.sh
```
