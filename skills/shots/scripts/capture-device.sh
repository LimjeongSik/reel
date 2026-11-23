#!/usr/bin/env bash
# 실행 중인 iOS 시뮬레이터 또는 연결된 Android 기기의 현재 화면을 PNG로 찍는다.
#
# 사용법:
#   capture-device.sh ios <out.png>       # 부팅된 시뮬레이터 (xcrun simctl)
#   capture-device.sh android <out.png>   # adb로 연결된 기기 · 에뮬레이터
#   DEVICE=<UDID 또는 adb 시리얼> capture-device.sh …   # 여러 대일 때 고른다(adb는 여러 대면 필수)
#
# 상태바를 9:41 · 배터리 가득으로 맞춰 찍고, 끝나면(실패해도) 찍기 전 상태로 되돌린다.
# 찍은 조건은 <out 폴더>/capture-log.tsv에 한 줄 남긴다(촬영 시각 · 플랫폼 · 기기 · 화면 크기 · 테마 · 파일).
# 화면 이동은 사람이 (또는 딥링크로) 하고, 이 스크립트는 지금 보이는 화면만 찍는다.
# 딥링크로 이동: ios → xcrun simctl openurl booted "<scheme>://path"
#               android → adb shell am start -a android.intent.action.VIEW -d "<scheme>://path"
# 다크 모드:    ios → xcrun simctl ui booted appearance dark
#               android → adb shell cmd uimode night yes
set -euo pipefail

if [ $# -lt 2 ]; then
    sed -n 2,16p "$0"
    exit 1
fi

platform="$1"; out="$2"
mkdir -p "$(dirname "$out")"
log="$(dirname "$out")/capture-log.tsv"
device="${DEVICE:-}"
size="-"; theme="-"

case "$platform" in
    ios)
        if ! xcrun simctl list devices booted | grep -q Booted; then
            echo "부팅된 iOS 시뮬레이터가 없습니다." >&2
            exit 1
        fi
        if [ -z "$device" ]; then
            if [ "$(xcrun simctl list devices booted | grep -c Booted)" -gt 1 ]; then
                echo "부팅된 시뮬레이터가 여러 대라 'booted'는 그중 하나만 가리킵니다. DEVICE=<UDID>로 고르세요:" >&2
                xcrun simctl list devices booted | grep Booted >&2
                exit 1
            fi
            device=booted
        fi
        name="$(xcrun simctl list devices booted | grep -F -- "$([ "$device" = booted ] && echo Booted || echo "$device")" | head -1 | sed 's/^[[:space:]]*//')"
        theme="$(xcrun simctl ui "$device" appearance 2>/dev/null || echo -)"
        # 상태바를 깔끔하게(9:41, 배터리 가득) 맞춘 뒤 찍고, 끝나면 되돌린다.
        trap 'xcrun simctl status_bar "$device" clear >/dev/null 2>&1 || true' EXIT
        xcrun simctl status_bar "$device" override --time "9:41" --batteryState charged --batteryLevel 100 \
            --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
        xcrun simctl io "$device" screenshot "$out"
        ;;
    android)
        adb_() { if [ -n "$device" ]; then adb -s "$device" "$@"; else adb "$@"; fi; }
        if [ -z "$device" ] && [ "$(adb devices | awk 'NR > 1 && $2 == "device"' | wc -l)" -gt 1 ]; then
            echo "adb 기기가 여러 대입니다. DEVICE=<시리얼>로 고르세요:" >&2
            adb devices | awk 'NR > 1 && $2 == "device" { print "  " $1 }' >&2
            exit 1
        fi
        if ! adb_ get-state >/dev/null 2>&1; then
            echo "adb로 연결된 기기가 없습니다${device:+ ($device)}." >&2
            exit 1
        fi
        name="$(adb_ shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
        size="$(adb_ shell wm size 2>/dev/null | tr -d '\r' | awk -F': ' 'END { print $2 }')"
        theme="$(adb_ shell cmd uimode night 2>/dev/null | tr -d '\r' | awk -F': ' '{ print $2 }')"
        # 데모 모드로 상태바를 고정하고, 끝나면 데모 모드를 끄고 원래 허용 설정으로 되돌린다.
        prev="$(adb_ shell settings get global sysui_demo_allowed 2>/dev/null | tr -d '\r' || echo null)"
        restore() {
            adb_ shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null 2>&1 || true
            if [ -z "$prev" ] || [ "$prev" = null ]; then
                adb_ shell settings delete global sysui_demo_allowed >/dev/null 2>&1 || true
            else
                adb_ shell settings put global sysui_demo_allowed "$prev" >/dev/null 2>&1 || true
            fi
        }
        trap restore EXIT
        demo() { adb_ shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null 2>&1 || true; }
        adb_ shell settings put global sysui_demo_allowed 1 >/dev/null 2>&1 || true
        demo enter
        demo clock -e hhmm 0941
        demo battery -e level 100 -e plugged false
        demo network -e wifi show -e level 4
        demo notifications -e visible false
        adb_ exec-out screencap -p > "$out"
        ;;
    *)
        echo "platform은 ios 또는 android" >&2
        exit 1
        ;;
esac

if [ "$size" = "-" ] && command -v sips >/dev/null; then
    size="$(sips -g pixelWidth -g pixelHeight "$out" 2>/dev/null | awk '/pixelWidth/ { w = $2 } /pixelHeight/ { h = $2 } END { if (w) print w "x" h }')"
fi
[ -f "$log" ] || printf '촬영 시각\t대상\t기기\t화면 크기\t테마\t파일\t옵션\n' > "$log"
printf '%s\t%s\t%s\t%s\t%s\t%s\t-\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$platform" "${name:-$device}" "${size:--}" "${theme:--}" "$(basename "$out")" >> "$log"
echo "saved: $out"
