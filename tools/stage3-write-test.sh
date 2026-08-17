#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Stage 3 low-risk, reversible write tests for JiaoLongOnArch.
#
# This script exercises only the reviewed stage 3 interfaces:
#   keyboard brightness 0-3
#   keyboard mode off/cyclic/fixed
#   platform profile quiet/balanced/performance
#
# It intentionally never writes fan_boost, gpu_mode, UMA, EC RAM, SMU,
# or any arbitrary WMI method. Each write is followed by a readback and
# a configurable cooldown (default 60 seconds).
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
control_guid="B60BFB48-3E5B-49E4-A0E9-8CFFE1B3434B"
wait_seconds=${WAIT_SECONDS:-60}
stamp=$(date +%Y%m%d-%H%M%S)
out_dir="/home/tanp/Projects/JiaoLongOnArch-stage3-$stamp"
log="$out_dir/run.log"
mkdir -p "$out_dir"

log_line() {
    printf '%s %s\n' "$(date --iso-8601=seconds)" "$*" | tee -a "$log"
}

cleanup_trap() {
    local rc=$?
    log_line "stage3 interrupted rc=$rc"
    exit "$rc"
}
trap cleanup_trap INT TERM

error_trap() {
    local rc=$?
    log_line "stage3 ERROR rc=$rc command=$BASH_COMMAND"
    exit "$rc"
}
trap error_trap ERR

skip_brightness=${STAGE3_SKIP_BRIGHTNESS:-0}
skip_kb_mode=${STAGE3_SKIP_KB_MODE:-0}
skip_profile=${STAGE3_SKIP_PROFILE:-0}
kb_modes=(off cyclic fixed)
if [[ -n ${STAGE3_KB_MODES:-} ]]; then
    read -r -a kb_modes <<<"$STAGE3_KB_MODES"
fi

read_value() {
    local path=$1
    if [[ -r "$path" ]]; then
        tr -d '\000' <"$path" | sed -e 's/[[:space:]]*$//' -e '/^$/d'
    else
        echo "<unreadable>"
    fi
}

find_control_device() {
    local device
    for device in /sys/bus/wmi/devices/"$control_guid"-*; do
        if [[ -e "$device/kb_mode" ]]; then
            printf '%s\n' "$device"
            return 0
        fi
    done
    return 1
}

find_profile_device() {
    local profile
    for profile in /sys/class/platform-profile/*; do
        [[ -d "$profile" ]] || continue
        if [[ "$(read_value "$profile/name")" == "bitland-mifs-wmi" ]]; then
            printf '%s\n' "$profile"
            return 0
        fi
    done
    return 1
}

if [[ ${EUID} -ne 0 ]]; then
    echo "error: stage 3 requires root; dry-run is available without root" >&2
    exit 4
fi

log_line "stage3 start wait_seconds=$wait_seconds repo=$repo skip_brightness=$skip_brightness skip_kb_mode=$skip_kb_mode skip_profile=$skip_profile kb_modes=${kb_modes[*]}"

if ! "$repo/tools/jiaolongctl" status | tee -a "$log"; then
    echo "error: jiaolongctl status is not ready" >&2
    exit 5
fi

led="/sys/class/leds/bitland-mifs-wmi::kbd_backlight"
control=$(find_control_device)
profile=$(find_profile_device)

[[ -r "$led/brightness" ]] || { echo "error: keyboard LED not found" >&2; exit 6; }
[[ -r "$control/kb_mode" ]] || { echo "error: kb_mode not found" >&2; exit 6; }
[[ -r "$profile/profile" ]] || { echo "error: platform profile not found" >&2; exit 6; }

baseline_brightness=$(read_value "$led/brightness")
baseline_kb_mode=$(read_value "$control/kb_mode")
baseline_profile=$(read_value "$profile/profile")

log_line "baseline brightness=$baseline_brightness kb_mode=$baseline_kb_mode profile=$baseline_profile"

write_and_verify() {
    local title=$1
    shift
    log_line "WRITE $title: $*"
    "$@" 2>&1 | tee -a "$log"
    sleep "$wait_seconds"
}

# 1. Keyboard brightness 0-3, then restore baseline.
if [[ "$skip_brightness" != 1 ]]; then
    for level in 0 1 2 3; do
        before=$(read_value "$led/brightness")
        write_and_verify "keyboard-brightness level=$level" \
            "$repo/tools/jiaolongctl" keyboard-brightness "$level"
        after=$(read_value "$led/brightness")
        log_line "READBACK keyboard-brightness before=$before after=$after expected=$level"
        [[ "$after" == "$level" ]] || { echo "error: keyboard brightness readback mismatch" >&2; exit 7; }
    done
    if [[ "$baseline_brightness" =~ ^[0-3]$ ]]; then
        write_and_verify "restore keyboard-brightness" \
            "$repo/tools/jiaolongctl" keyboard-brightness "$baseline_brightness"
    fi
else
    log_line "skip keyboard-brightness block"
fi

# 2. Keyboard modes off/cyclic/fixed, then restore baseline.
if [[ "$skip_kb_mode" != 1 ]]; then
    for mode in "${kb_modes[@]}"; do
        before=$(read_value "$control/kb_mode")
        write_and_verify "keyboard-mode mode=$mode" \
            "$repo/tools/jiaolongctl" keyboard-mode "$mode"
        after=$(read_value "$control/kb_mode")
        log_line "READBACK keyboard-mode before=$before after=$after expected=$mode"
        [[ "$after" == "$mode" ]] || { echo "error: keyboard mode readback mismatch" >&2; exit 7; }
    done
    case "$baseline_kb_mode" in
        off|cyclic|fixed|custom)
            write_and_verify "restore keyboard-mode" \
                "$repo/tools/jiaolongctl" keyboard-mode "$baseline_kb_mode"
            ;;
        *)
            log_line "baseline kb_mode=$baseline_kb_mode is outside reviewed set; leaving as-is"
            ;;
    esac
else
    log_line "skip keyboard-mode block"
fi

# 3. Profiles quiet/balanced/performance, then restore baseline.
if [[ "$skip_profile" == 1 ]]; then
    log_line "skip profile block"
fi
profile_mode_for_value() {
    case "$1" in
        low-power) printf 'quiet\n' ;;
        balanced) printf 'balanced\n' ;;
        balanced-performance) printf 'performance\n' ;;
        *) printf '\n' ;;
    esac
}
if [[ "$skip_profile" != 1 ]]; then
    for mode in quiet balanced performance; do
        before=$(read_value "$profile/profile")
        write_and_verify "profile mode=$mode" \
            "$repo/tools/jiaolongctl" profile "$mode"
        after=$(read_value "$profile/profile")
        log_line "READBACK profile before=$before after=$after mode=$mode"
    done
    restore_profile_mode=$(profile_mode_for_value "$baseline_profile")
    if [[ -n "$restore_profile_mode" ]]; then
        write_and_verify "restore profile" \
            "$repo/tools/jiaolongctl" profile "$restore_profile_mode"
    else
        log_line "baseline profile=$baseline_profile is outside reviewed set; not restored automatically"
    fi
fi

log_line "stage3 done log=$log"
