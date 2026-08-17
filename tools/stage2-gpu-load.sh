#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# NVIDIA-only load runner for JiaoLongOnArch stage 2 fan identification.
#
# This script runs read-only samplers and user-space NVIDIA load generators
# (vkcube and/or ffmpeg hevc_nvenc). It never writes platform_profile,
# gpu_mode, kb_mode, fan_boost, LED brightness, EC RAM, or any WMI method.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
duration=${1:-240}
cooldown=${2:-120}
stamp=$(date +%Y%m%d-%H%M%S)
out_dir="/home/tanp/Projects/JiaoLongOnArch-stage2-gpu-$stamp"
hashcat_device=${HASHCAT_DEVICE:-}
mkdir -p "$out_dir"

fan_csv="$out_dir/fans.csv"
gpu_csv="$out_dir/gpu.csv"
load_log="$out_dir/loaders.log"

logger_pid=
sampler_pid=
load_pids=()

cleanup() {
    local pid
    for pid in "${load_pids[@]:-}" "$logger_pid" "$sampler_pid"; do
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
}
trap cleanup EXIT INT TERM

if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "error: nvidia-smi is required in this terminal" >&2
    exit 2
fi

if ! command -v vkcube >/dev/null 2>&1 && ! command -v ffmpeg >/dev/null 2>&1; then
    echo "error: vkcube or ffmpeg is required" >&2
    exit 2
fi

python3 -u "$repo/tools/fan-sample.py" --no-gpu --duration "$((duration + cooldown))" --interval 1 >"$fan_csv" &
sampler_pid=$!

nvidia-smi \
    --query-gpu=timestamp,temperature.gpu,utilization.gpu,power.draw,clocks.sm,clocks.mem,power.limit,enforced.power.limit \
    --format=csv,nounits -l 1 -f "$gpu_csv" &
logger_pid=$!

if [[ -n "$hashcat_device" ]]; then
    if ! command -v hashcat >/dev/null 2>&1; then
        echo "error: HASHCAT_DEVICE is set but hashcat is not installed" >&2
        exit 2
    fi
    timeout "$duration" hashcat -b --benchmark-all -d "$hashcat_device" \
        >"$out_dir/hashcat.log" 2>&1 &
    load_pids+=("$!")
elif command -v ffmpeg >/dev/null 2>&1; then
    for stream in 1 2 3; do
        ffmpeg -hide_banner -loglevel error \
            -f lavfi -i testsrc2=size=2560x1440:rate=60 \
            -t "$duration" -c:v hevc_nvenc -preset p1 -b:v 40M -f null - \
            >"$out_dir/ffmpeg-$stream.log" 2>&1 &
        load_pids+=("$!")
    done
fi

if [[ -z "$hashcat_device" ]] && command -v vkcube >/dev/null 2>&1; then
    for cube in 1 2; do
        __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia \
            vkcube --wsi wayland --width 1920 --height 1080 --present_mode 0 \
            >"$out_dir/vkcube-$cube.log" 2>&1 &
        load_pids+=("$!")
    done
fi

echo "stage2-gpu-load: duration=${duration}s cooldown=${cooldown}s hashcat_device=${hashcat_device:-none}"
echo "stage2-gpu-load: fan_csv=$fan_csv"
echo "stage2-gpu-load: gpu_csv=$gpu_csv"
echo "stage2-gpu-load: loaders=${load_pids[*]}"
echo "Keep at least one vkcube window visible while the load is running."

for ((elapsed = 0; elapsed < duration; elapsed += 10)); do
    sleep 10
    nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,power.draw,clocks.sm,clocks.mem,enforced.power.limit --format=csv,noheader || true
done

for pid in "${load_pids[@]:-}"; do
    kill "$pid" 2>/dev/null || true
done

echo "stage2-gpu-load: load finished; cooldown ${cooldown}s"
sleep "$cooldown"

kill "$logger_pid" 2>/dev/null || true
wait "$sampler_pid"
echo "stage2-gpu-load: done; $fan_csv / $gpu_csv"
