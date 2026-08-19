#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Read-only stage 5 post-cycle checker.
# Usage: ./tools/stage5-check.sh <label>
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
label=${1:-cycle}
output_dir=${STAGE5_OUTPUT_DIR:-"$repo/artifacts"}
mkdir -p "$output_dir"
out="$output_dir/JiaoLongOnArch-stage5-${label}-$(date +%Y%m%d-%H%M%S).log"

{
    echo "stage5 label=$label"
    date --iso-8601=seconds
    uname -srvm
    echo
    echo "=== jiaolongctl status ==="
    "$repo/tools/jiaolongctl" status
    status_rc=$?
    echo "jiaolongctl_status_rc=$status_rc"
    echo
    echo "=== power supplies ==="
    for supply in /sys/class/power_supply/*; do
        [[ -d "$supply" ]] || continue
        echo "$(basename "$supply") type=$(cat "$supply/type" 2>/dev/null) online=$(cat "$supply/online" 2>/dev/null)"
    done
    echo
    echo "=== WMI/ACPI errors since boot ==="
    journalctl -b --no-pager 2>/dev/null \
        | grep -Ei 'ACPI Error|ACPI BIOS Error|bitland|mifs|WMI.*(error|fail)|firmware.*(error|fail)' \
        || true
    echo
    echo "=== kwin_wayland warnings since boot ==="
    journalctl -b -t kwin_wayland --no-pager 2>/dev/null \
        | grep -Ei 'error|fail|atomic|legacy|framebuffer' || true
} >"$out" 2>&1

cat "$out"
echo
echo "stage5 report: $out"
