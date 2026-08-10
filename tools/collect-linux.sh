#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Read-only Linux collector for JiaoLongOnArch.
set -euo pipefail

stamp=$(date +%Y%m%d-%H%M%S)
out_dir=${1:-"$PWD/JiaoLongOnArch-Probe-$stamp"}
archive="${out_dir}.tar.gz"
mkdir -p "$out_dir"

copy_value() {
    local source=$1
    local destination=$2
    if [[ -r "$source" ]]; then
        tr -d '\000' <"$source" >"$out_dir/$destination"
        printf '\n' >>"$out_dir/$destination"
    fi
}

{
    printf 'collected_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'kernel=%s\n' "$(uname -srvm)"
    printf 'architecture=%s\n' "$(uname -m)"
} >"$out_dir/system.txt"

# Deliberately excludes product UUID and every serial-number field.
for field in sys_vendor product_name product_version board_vendor board_name board_version bios_vendor bios_version bios_date; do
    copy_value "/sys/class/dmi/id/$field" "dmi-$field.txt"
done

{
    for device in /sys/bus/wmi/devices/*; do
        [[ -e "$device" ]] || continue
        basename "$device"
    done
} | sort >"$out_dir/wmi-guids.txt"

{
    printf 'expected_control_guid=B60BFB48-3E5B-49E4-A0E9-8CFFE1B3434B\n'
    printf 'expected_event_guid=46C93E13-EE9B-4262-8488-563BCA757FEF\n'
    for guid in B60BFB48-3E5B-49E4-A0E9-8CFFE1B3434B 46C93E13-EE9B-4262-8488-563BCA757FEF; do
        path="/sys/bus/wmi/devices/$guid"
        if [[ -e "$path" ]]; then
            printf '%s=present\n' "$guid"
            if [[ -L "$path/driver" ]]; then
                printf '%s_driver=%s\n' "$guid" "$(basename "$(readlink -f "$path/driver")")"
            fi
        else
            printf '%s=absent\n' "$guid"
        fi
    done
} >"$out_dir/mifs-status.txt"

if [[ -r /proc/config.gz ]]; then
    zgrep -E 'CONFIG_(BITLAND_MIFS_WMI|ACPI_WMI|HWMON|LEDS_CLASS|ACPI_PLATFORM_PROFILE)=' \
        /proc/config.gz >"$out_dir/kernel-config.txt" || true
fi

if command -v modinfo >/dev/null 2>&1; then
    modinfo bitland-mifs-wmi >"$out_dir/bitland-module.txt" 2>&1 || true
fi

if command -v lspci >/dev/null 2>&1; then
    lspci -nnk >"$out_dir/lspci-nnk.txt" 2>&1 || true
fi

{
    for hwmon in /sys/class/hwmon/hwmon*; do
        [[ -r "$hwmon/name" ]] || continue
        name=$(<"$hwmon/name")
        [[ "$name" == "bitland_mifs" ]] || continue
        printf '[%s name=%s]\n' "$hwmon" "$name"
        for value in "$hwmon"/temp*_input "$hwmon"/fan*_input "$hwmon"/fan*_label; do
            [[ -r "$value" ]] || continue
            printf '%s=%s\n' "$(basename "$value")" "$(<"$value")"
        done
    done
} >"$out_dir/hwmon-readings.txt"

{
    for profile in /sys/class/platform-profile/*; do
        [[ -d "$profile" ]] || continue
        printf '[%s]\n' "$profile"
        for value in name choices profile; do
            [[ -r "$profile/$value" ]] || continue
            printf '%s=%s\n' "$value" "$(<"$profile/$value")"
        done
    done
    for value in /sys/firmware/acpi/platform_profile /sys/firmware/acpi/platform_profile_choices; do
        [[ -r "$value" ]] || continue
        printf '%s=%s\n' "$value" "$(<"$value")"
    done
} >"$out_dir/platform-profiles.txt"

{
    for device in /sys/bus/wmi/drivers/bitland-mifs-wmi/*; do
        [[ -d "$device" ]] || continue
        printf '[%s]\n' "$device"
        for value in gpu_mode kb_mode; do
            [[ -r "$device/$value" ]] || continue
            printf '%s=%s\n' "$value" "$(<"$device/$value")"
        done
    done
} >"$out_dir/bitland-readings.txt"

cat >"$out_dir/README.txt" <<'NOTICE'
This report is read-only. The collector does not write platform_profile,
gpu_mode, kb_mode, fan_boost, keyboard brightness, EC RAM, or any WMI method.
It intentionally excludes serial numbers, UUIDs, MAC addresses, and PNP IDs.
NOTICE

tar -C "$(dirname "$out_dir")" -czf "$archive" "$(basename "$out_dir")"
rm -rf "$out_dir"
printf 'Read-only report created: %s\n' "$archive"
