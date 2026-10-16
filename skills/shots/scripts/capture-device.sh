#!/usr/bin/env bash
# 실행 중인 iOS 시뮬레이터 또는 연결된 Android 기기의 현재 화면을 PNG로 찍는다.
#
# 사용법:
#   capture-device.sh ios <out.png>       # 부팅된 시뮬레이터 (xcrun simctl)
#   capture-device.sh android <out.png>   # adb로 연결된 기기 · 에뮬레이터
#
# 화면 이동은 사람이 (또는 딥링크로) 하고, 이 스크립트는 지금 보이는 화면만 찍는다.
# 딥링크로 이동: ios → xcrun simctl openurl booted "<scheme>://path"
#               android → adb shell am start -a android.intent.action.VIEW -d "<scheme>://path"
# 다크 모드:    ios → xcrun simctl ui booted appearance dark
#               android → adb shell cmd uimode night yes
set -euo pipefail

if [ $# -lt 2 ]; then
    sed -n 2,12p "$0"
    exit 1
fi

platform="$1"; out="$2"
mkdir -p "$(dirname "$out")"

case "$platform" in
    ios)
        if ! xcrun simctl list devices booted | grep -q Booted; then
            echo "부팅된 iOS 시뮬레이터가 없습니다." >&2
            exit 1
        fi
        # 상태바를 깔끔하게(9:41, 배터리 가득) 맞춘 뒤 찍는다.
        xcrun simctl status_bar booted override --time "9:41" --batteryState charged --batteryLevel 100 \
            --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
        xcrun simctl io booted screenshot "$out"
        ;;
    android)
        if ! adb get-state >/dev/null 2>&1; then
            echo "adb로 연결된 기기가 없습니다." >&2
            exit 1
        fi
        # 데모 모드로 상태바 고정 (지원하지 않는 기기면 무시)
        adb shell settings put global sysui_demo_allowed 1 >/dev/null 2>&1 || true
        adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null 2>&1 || true
        adb exec-out screencap -p > "$out"
        ;;
    *)
        echo "platform은 ios 또는 android" >&2
        exit 1
        ;;
esac
echo "saved: $out"
